package pe.com.dentalamericana.messaging;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.appointment.*;
import pe.com.dentalamericana.audit.*;
import pe.com.dentalamericana.common.ResourceNotFoundException;
import pe.com.dentalamericana.messaging.dto.MessagingDtos.*;
import pe.com.dentalamericana.patient.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.time.Instant;
import java.util.*;

@Service
public class MessagingService implements MetaWebhookEventHandler {
    private static final List<String> ALERTS = List.of(
            "sangrado abundante", "no para de sangrar", "fiebre", "hinchazón severa",
            "hinchazon severa", "dificultad para respirar", "dolor insoportable", "alergia");
    private static final Set<String> APPOINTMENT_INTENTS = Set.of("CONFIRMAR", "REPROGRAMAR", "CANCELAR");

    private final WhatsAppMessageRepository messages;
    private final WhatsAppConversationRepository conversations;
    private final PostConsultationFollowUpRepository followups;
    private final PatientRepository patientRepo;
    private final PatientService patients;
    private final AppointmentRepository appointments;
    private final AppointmentStatusHistoryRepository histories;
    private final MessageOutboxService outbox;
    private final PhoneNumberNormalizer phoneNumbers;
    private final AuditService audit;

    public MessagingService(WhatsAppMessageRepository messages, WhatsAppConversationRepository conversations,
                            PostConsultationFollowUpRepository followups, PatientRepository patientRepo,
                            PatientService patients, AppointmentRepository appointments,
                            AppointmentStatusHistoryRepository histories, MessageOutboxService outbox,
                            PhoneNumberNormalizer phoneNumbers, AuditService audit) {
        this.messages = messages;
        this.conversations = conversations;
        this.followups = followups;
        this.patientRepo = patientRepo;
        this.patients = patients;
        this.appointments = appointments;
        this.histories = histories;
        this.outbox = outbox;
        this.phoneNumbers = phoneNumbers;
        this.audit = audit;
    }

    @Transactional(readOnly = true)
    public List<MessageResponse> messages() {
        return messages.findTop50ByOrderByCreatedAtDesc().stream().map(this::message).toList();
    }

    @Transactional(readOnly = true)
    public List<FollowUpResponse> followups() {
        return followups.findAllByOrderByScheduledForDesc().stream().map(this::followup).toList();
    }

    @Transactional
    public MessageResponse manual(ManualMessageRequest request, AuthenticatedUser actor, HttpServletRequest http) {
        Patient patient = patients.find(request.patientId());
        WhatsAppMessage message = outbox.queueManual(patient, request.content().trim(), request.scheduledFor(), actor.getId());
        record(actor, "PROGRAMAR_MENSAJE", message.getId(), "Paciente " + patient.getHistoryNumber(), http);
        return message(message);
    }

    @Transactional
    public MessageResponse incoming(String rawPhone, String content, String providerId, String contextProviderId) {
        if (providerId != null) {
            Optional<WhatsAppMessage> duplicate = messages.findByProviderId(providerId);
            if (duplicate.isPresent()) return message(duplicate.get());
        }
        String phone = phoneNumbers.outbound(rawPhone);
        Patient patient = patientRepo.findFirstByCelularIn(phoneNumbers.lookupCandidates(phone)).orElse(null);
        WhatsAppConversation conversation = conversations
                .findFirstByTelefonoAndEstadoNot(phone, ConversationStatus.CERRADA)
                .orElseGet(() -> conversations.save(new WhatsAppConversation(patient == null ? null : patient.getId(), phone)));
        String text = content.trim();
        String intent = classify(text);
        boolean review = Set.of("REPROGRAMAR", "CANCELAR", "NO_ENTENDIDO", "ALERTA_CLINICA").contains(intent);
        WhatsAppMessage received = messages.save(WhatsAppMessage.incoming(conversation.getId(),
                patient == null ? null : patient.getId(), providerId, text, intent, review));
        conversation.touch();
        if (review) conversation.derive();
        if (patient != null) processPatientReply(patient, text, intent, contextProviderId);
        return message(received);
    }

    @Override
    @Transactional
    public void handleIncoming(String phone, String content, String providerId, String contextProviderId) {
        incoming(phone, content, providerId, contextProviderId);
    }

    @Override
    @Transactional
    public void providerStatus(String providerId, MessageStatus status, String error) {
        if (providerId == null || providerId.isBlank()) return;
        messages.findByProviderId(providerId).ifPresent(message -> message.providerStatus(status, error));
    }

    @Transactional
    public FollowUpResponse review(Long id, ReviewRequest request, AuthenticatedUser actor, HttpServletRequest http) {
        PostConsultationFollowUp followUp = followups.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Seguimiento no encontrado"));
        if (!followUp.getVersion().equals(request.version())) throw new IllegalStateException("El seguimiento fue modificado");
        followUp.review(actor.getId());
        record(actor, "REVISAR_SEGUIMIENTO", id, followUp.getClassification(), http);
        return followup(followUp);
    }

    private void processPatientReply(Patient patient, String text, String intent, String contextProviderId) {
        if ("CONFIRMAR".equals(intent)) confirmNextAppointment(patient);
        PostConsultationFollowUp followUp = contextualFollowUp(contextProviderId);
        if (followUp == null && !APPOINTMENT_INTENTS.contains(intent)) {
            followUp = followups.findFirstByPatientIdAndEstadoInOrderByScheduledForDesc(patient.getId(),
                    List.of(FollowUpStatus.PROGRAMADO, FollowUpStatus.ENVIADO)).orElse(null);
        }
        if (followUp != null) {
            String alert = alertReason(text);
            followUp.respond(text, alert == null ? "RESPUESTA_RECIBIDA" : "REQUIERE_REVISION", alert);
        }
    }

    private PostConsultationFollowUp contextualFollowUp(String contextProviderId) {
        if (contextProviderId == null || contextProviderId.isBlank()) return null;
        return messages.findByProviderId(contextProviderId)
                .flatMap(message -> followups.findByMessageId(message.getId()))
                .orElse(null);
    }

    private void confirmNextAppointment(Patient patient) {
        appointments.findFirstByPatientIdAndInicioAfterAndEstadoOrderByInicioAsc(
                patient.getId(), Instant.now(), AppointmentStatus.PENDIENTE_CONFIRMACION).ifPresent(appointment -> {
            AppointmentStatus before = appointment.getStatus();
            appointment.changeStatus(AppointmentStatus.CONFIRMADA, null, appointment.getUpdatedBy());
            histories.save(new AppointmentStatusHistory(appointment.getId(), before, AppointmentStatus.CONFIRMADA,
                    "Confirmado por WhatsApp", appointment.getUpdatedBy()));
        });
    }

    private String classify(String text) {
        String normalized = text.toLowerCase(Locale.ROOT);
        if (ALERTS.stream().anyMatch(normalized::contains)) return "ALERTA_CLINICA";
        if (normalized.contains("confirmo") || normalized.equals("si") || normalized.equals("sí")) return "CONFIRMAR";
        if (normalized.contains("reprogram") || normalized.contains("cambiar") || normalized.contains("otro horario")) return "REPROGRAMAR";
        if (normalized.contains("cancel")) return "CANCELAR";
        return "NO_ENTENDIDO";
    }

    private String alertReason(String text) {
        String normalized = text.toLowerCase(Locale.ROOT);
        return ALERTS.stream().filter(normalized::contains).findFirst()
                .map(value -> "Expresión de alerta detectada: " + value).orElse(null);
    }

    private MessageResponse message(WhatsAppMessage message) {
        String name = message.getPatientId() == null ? "Número no identificado" : patientName(patients.find(message.getPatientId()));
        return MessageResponse.of(message, name);
    }

    private FollowUpResponse followup(PostConsultationFollowUp followUp) {
        return new FollowUpResponse(followUp.getId(), followUp.getPatientId(),
                patientName(patients.find(followUp.getPatientId())), followUp.getEncounterId(), followUp.getMessageId(),
                followUp.getScheduledFor(), followUp.getStatus(), followUp.getResponse(), followUp.getClassification(),
                followUp.getAlertReason(), followUp.getReviewedBy(), followUp.getReviewedAt(), followUp.getVersion());
    }

    private String patientName(Patient patient) { return patient.getFirstNames() + " " + patient.getPaternalSurname(); }
    private void record(AuthenticatedUser actor, String action, Long id, String detail, HttpServletRequest http) {
        audit.record(patients.actorEntity(actor), action, "SEGUIMIENTO", id.toString(), AuditResult.EXITO, detail, http);
    }
}
