package pe.com.dentalamericana.messaging;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.appointment.*;
import pe.com.dentalamericana.audit.*;
import pe.com.dentalamericana.booking.PublicBookingRequest;
import pe.com.dentalamericana.booking.PublicBookingRequestRepository;
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
    private static final Set<String> APPOINTMENT_INTENTS = Set.of("CONFIRMAR", "REPROGRAMAR", "CANCELAR", "RESERVAR");

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
    private final PublicBookingRequestRepository bookingRequests;

    public MessagingService(WhatsAppMessageRepository messages, WhatsAppConversationRepository conversations,
                            PostConsultationFollowUpRepository followups, PatientRepository patientRepo,
                            PatientService patients, AppointmentRepository appointments,
                            AppointmentStatusHistoryRepository histories, MessageOutboxService outbox,
                            PhoneNumberNormalizer phoneNumbers, AuditService audit,
                            PublicBookingRequestRepository bookingRequests) {
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
        this.bookingRequests = bookingRequests;
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
        List<Patient> matches = patientRepo.findAllByCelularIn(phoneNumbers.lookupCandidates(phone));
        Patient patient = matches.size() == 1 && matches.get(0).isActive() ? matches.get(0) : null;
        WhatsAppConversation conversation = conversations
                .findFirstByTelefonoAndEstadoNot(phone, ConversationStatus.CERRADA)
                .orElseGet(() -> conversations.save(new WhatsAppConversation(patient == null ? null : patient.getId(), phone)));
        String text = content.trim();
        String intent = classify(text);
        boolean review = patient == null || !"AYUDA".equals(intent);
        WhatsAppMessage received = messages.save(WhatsAppMessage.incoming(conversation.getId(),
                patient == null ? null : patient.getId(), providerId, text, intent, review));
        conversation.touch();
        if (review) conversation.derive();
        if (patient != null) processPatientReply(patient, text, intent, contextProviderId);
        else if ("RESERVAR".equals(intent) || "REPROGRAMAR".equals(intent)) {
            bookingRequests.save(new PublicBookingRequest("Contacto WhatsApp por identificar", null, phone, null,
                    "Solicitud WhatsApp", null, "INDIFERENTE", text));
        }
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
        if ("CONFIRMAR".equals(intent)) confirmAppointment(patient, contextProviderId);
        if ("CANCELAR".equals(intent)) cancelAppointment(patient, contextProviderId);
        if ("REPROGRAMAR".equals(intent)) createCoordinationRequest(patient, "REPROGRAMACIÓN", text, contextProviderId);
        if ("RESERVAR".equals(intent)) createCoordinationRequest(patient, "NUEVA CITA", text, null);
        if ("ALERTA_CLINICA".equals(intent)) {
            reply(patient, "Recibimos su mensaje y lo derivamos al odontólogo para revisión prioritaria. Si tiene dificultad para respirar o una emergencia, acuda a urgencias.");
        }
        if ("NO_ENTENDIDO".equals(intent) || "AYUDA".equals(intent)) {
            reply(patient, "Puedo ayudarle con su cita. Responda CONFIRMO, CANCELAR, REPROGRAMAR o RESERVAR. Si necesita atención clínica, escriba su consulta y la revisará el odontólogo.");
        }
        PostConsultationFollowUp followUp = contextualFollowUp(contextProviderId);
        if (followUp != null && !followUp.getPatientId().equals(patient.getId())) return;
        if (followUp == null && !APPOINTMENT_INTENTS.contains(intent)) {
            followUp = followups.findFirstByPatientIdAndEstadoInOrderByScheduledForDesc(patient.getId(),
                    List.of(FollowUpStatus.ENVIADO)).orElse(null);
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

    private void confirmAppointment(Patient patient, String contextProviderId) {
        selectAppointment(patient, contextProviderId).ifPresent(appointment -> {
            if (appointment.getStatus() == AppointmentStatus.PENDIENTE_CONFIRMACION) confirm(appointment);
            reply(patient, "Su cita del " + appointmentTime(appointment) + " está confirmada.");
        });
    }

    private void confirm(Appointment appointment) {
            AppointmentStatus before = appointment.getStatus();
            appointment.changeStatus(AppointmentStatus.CONFIRMADA, null, appointment.getUpdatedBy());
            histories.save(new AppointmentStatusHistory(appointment.getId(), before, AppointmentStatus.CONFIRMADA,
                    "Confirmado por WhatsApp", appointment.getUpdatedBy()));
            audit.record(null, "WHATSAPP_CONFIRMAR_CITA", "CITA", appointment.getId().toString(), AuditResult.EXITO,
                    "Acción solicitada por paciente " + appointment.getPatientId(), null);
    }

    /** Cancels only an upcoming appointment belonging to this patient. A clinical encounter is never altered by WhatsApp. */
    private void cancelAppointment(Patient patient, String contextProviderId) {
        selectAppointment(patient, contextProviderId).ifPresent(appointment -> {
            AppointmentStatus previous = appointment.getStatus();
            appointment.changeStatus(AppointmentStatus.CANCELADA, "Cancelada por el paciente vía WhatsApp", appointment.getUpdatedBy());
            outbox.cancelPendingAppointmentMessages(appointment.getId());
            histories.save(new AppointmentStatusHistory(appointment.getId(), previous, AppointmentStatus.CANCELADA,
                    "Cancelada automáticamente por WhatsApp", appointment.getUpdatedBy()));
            audit.record(null, "WHATSAPP_CANCELAR_CITA", "CITA", appointment.getId().toString(), AuditResult.EXITO,
                    "Acción solicitada por paciente " + patient.getId(), null);
            reply(patient, "Su cita del " + appointmentTime(appointment) + " fue cancelada. Si desea una nueva fecha, responda RESERVAR.");
        });
    }

    private Optional<Appointment> selectAppointment(Patient patient, String contextProviderId) {
        if (contextProviderId != null && !contextProviderId.isBlank()) {
            Optional<Appointment> selected = appointmentFromContext(patient, contextProviderId);
            if (selected.isEmpty()) reply(patient, "El mensaje citado no corresponde a una cita futura disponible. No cambiamos ninguna cita; el odontólogo revisará su solicitud.");
            return selected.filter(a -> canAutomateAppointment(patient, a));
        }
        List<Appointment> eligible = appointments.findAllByPatientIdAndInicioAfterAndEstadoInOrderByInicioAsc(
                patient.getId(), Instant.now(), List.of(AppointmentStatus.PENDIENTE_CONFIRMACION, AppointmentStatus.CONFIRMADA));
        if (eligible.size() == 1) return Optional.of(eligible.get(0)).filter(a -> canAutomateAppointment(patient, a));
        reply(patient, eligible.isEmpty() ? "No encontramos una cita futura. Para solicitar una nueva, escriba RESERVAR."
                : "Tiene varias citas futuras. Responda al mensaje de la cita que desea modificar usando la opción Responder de WhatsApp, o solicite ayuda al odontólogo.");
        return Optional.empty();
    }

    private boolean canAutomateAppointment(Patient patient, Appointment appointment) {
        if (!appointments.hasClinicalEncounter(appointment.getId())) return true;
        reply(patient, "Esta cita tiene una atención clínica registrada. El odontólogo revisará su solicitud antes de modificarla.");
        return false;
    }

    private String appointmentTime(Appointment appointment) {
        return java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm")
                .withZone(java.time.ZoneId.of("America/Lima")).format(appointment.getStart());
    }

    private Optional<Appointment> appointmentFromContext(Patient patient, String contextProviderId) {
        if (contextProviderId == null || contextProviderId.isBlank()) return Optional.empty();
        return messages.findByProviderId(contextProviderId)
                .filter(message -> patient.getId().equals(message.getPatientId()) && message.getAppointmentId() != null)
                .flatMap(message -> appointments.findById(message.getAppointmentId()))
                .filter(appointment -> appointment.getPatientId().equals(patient.getId())
                        && appointment.getStart().isAfter(Instant.now())
                        && Set.of(AppointmentStatus.PENDIENTE_CONFIRMACION, AppointmentStatus.CONFIRMADA).contains(appointment.getStatus()));
    }

    private void createCoordinationRequest(Patient patient, String kind, String text, String contextProviderId) {
        Optional<Appointment> related = "REPROGRAMACIÓN".equals(kind) ? selectAppointment(patient, contextProviderId) : Optional.empty();
        if ("REPROGRAMACIÓN".equals(kind) && related.isEmpty()) return;
        String note = "Solicitud por WhatsApp: " + kind
                + related.map(a -> "; cita #" + a.getId() + " del " + appointmentTime(a)).orElse("")
                + ". Mensaje: " + text;
        boolean existing = bookingRequests.findAllByEstadoOrderByCreatedAtDesc(pe.com.dentalamericana.booking.BookingRequestStatus.PENDIENTE)
                .stream().anyMatch(r -> phoneNumbers.outbound(patient.getMobile()).equals(r.getMobile())
                        && kind.equals(r.getService()) && r.getMessage() != null
                        && (related.isEmpty() || r.getMessage().contains("cita #" + related.get().getId() + " del ")));
        if (existing) {
            reply(patient, "Su solicitud ya está pendiente. El odontólogo coordinará el horario; la cita actual se conserva hasta confirmar el cambio.");
            return;
        }
        bookingRequests.save(new PublicBookingRequest(patientName(patient), null, phoneNumbers.outbound(patient.getMobile()), null,
                kind, null, "INDIFERENTE", note));
        reply(patient, "Registramos su solicitud de " + kind.toLowerCase(Locale.ROOT)
                + ". El odontólogo le propondrá un horario disponible. Su solicitud todavía no cambia la agenda.");
    }

    private void reply(Patient patient, String content) {
        if (patient.isWhatsAppConsent() && patient.getMobile() != null) {
            outbox.queueManual(patient, content, Instant.now(), null);
        }
    }

    private String classify(String text) {
        String normalized = text.toLowerCase(Locale.ROOT);
        if (ALERTS.stream().anyMatch(normalized::contains)) return "ALERTA_CLINICA";
        return AppointmentIntentClassifier.classify(text);
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
