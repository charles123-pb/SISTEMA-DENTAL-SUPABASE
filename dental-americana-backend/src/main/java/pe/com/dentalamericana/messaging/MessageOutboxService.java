package pe.com.dentalamericana.messaging;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.appointment.AppointmentRepository;
import pe.com.dentalamericana.patient.Patient;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Set;

@Service
public class MessageOutboxService {
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm");
    private static final Set<MessageStatus> ACTIVE = Set.of(MessageStatus.PENDIENTE, MessageStatus.ENVIADO,
            MessageStatus.ENTREGADO, MessageStatus.LEIDO);

    private final WhatsAppConversationRepository conversations;
    private final WhatsAppMessageRepository messages;
    private final PostConsultationFollowUpRepository followUps;
    private final AppointmentRepository appointments;
    private final WhatsAppGateway gateway;
    private final PhoneNumberNormalizer phoneNumbers;
    private final ObjectMapper mapper;
    private final String confirmationTemplate;
    private final String reminderTemplate;
    private final String followUpTemplate;
    private final int maxAttempts;

    public MessageOutboxService(WhatsAppConversationRepository conversations,
                                WhatsAppMessageRepository messages,
                                PostConsultationFollowUpRepository followUps,
                                AppointmentRepository appointments,
                                WhatsAppGateway gateway,
                                PhoneNumberNormalizer phoneNumbers,
                                ObjectMapper mapper,
                                @Value("${app.whatsapp.templates.appointment-confirmation:}") String confirmationTemplate,
                                @Value("${app.whatsapp.templates.appointment-reminder:}") String reminderTemplate,
                                @Value("${app.whatsapp.templates.follow-up:}") String followUpTemplate,
                                @Value("${app.whatsapp.max-attempts:3}") int maxAttempts) {
        this.conversations = conversations;
        this.messages = messages;
        this.followUps = followUps;
        this.appointments = appointments;
        this.gateway = gateway;
        this.phoneNumbers = phoneNumbers;
        this.mapper = mapper;
        this.confirmationTemplate = confirmationTemplate;
        this.reminderTemplate = reminderTemplate;
        this.followUpTemplate = followUpTemplate;
        this.maxAttempts = Math.max(1, Math.min(maxAttempts, 10));
    }

    @Transactional
    public WhatsAppMessage queueAppointmentConfirmation(Patient patient, Long appointmentId, Instant start,
                                                         ZoneId zone, Long actorId) {
        if (!canMessage(patient)) return null;
        var local = start.atZone(zone);
        String content = "Hola " + patient.getFirstNames() + ", su cita está programada para el "
                + DATE.format(local) + " a las " + TIME.format(local)
                + ". Responda CONFIRMO o solicite reprogramación.";
        return queue(patient, appointmentId, null, MessageType.CITA_CONFIRMACION, content, Instant.now(),
                confirmationTemplate, List.of(patient.getFirstNames(), DATE.format(local), TIME.format(local)), actorId);
    }

    @Transactional
    public WhatsAppMessage queueAppointmentReminder(Patient patient, Long appointmentId, Instant start,
                                                     Instant scheduledFor, ZoneId zone, Long actorId) {
        if (!canMessage(patient)) return null;
        if (messages.existsByAppointmentIdAndTipoAndEstadoIn(appointmentId, MessageType.CITA_RECORDATORIO, ACTIVE)) return null;
        var local = start.atZone(zone);
        String content = "Hola " + patient.getFirstNames() + ", le recordamos su cita del "
                + DATE.format(local) + " a las " + TIME.format(local) + ".";
        return queue(patient, appointmentId, null, MessageType.CITA_RECORDATORIO, content, scheduledFor,
                reminderTemplate, List.of(patient.getFirstNames(), DATE.format(local), TIME.format(local)), actorId);
    }

    @Transactional
    public WhatsAppMessage queueFollowUp(Patient patient, Long encounterId, Instant scheduledFor, Long actorId) {
        if (!canMessage(patient)) return null;
        String content = "Hola " + patient.getFirstNames()
                + ", ¿cómo se siente después de su atención? Puede responder con sus propias palabras.";
        return queue(patient, null, encounterId, MessageType.POSTCONSULTA, content, scheduledFor,
                followUpTemplate, List.of(patient.getFirstNames()), actorId);
    }

    @Transactional
    public WhatsAppMessage queueManual(Patient patient, String content, Instant scheduledFor, Long actorId) {
        if (patient.getMobile() == null) throw new IllegalStateException("El paciente no tiene celular");
        if (!patient.isWhatsAppConsent()) throw new IllegalStateException("El paciente no autorizó comunicaciones por WhatsApp");
        try {
            phoneNumbers.outbound(patient.getMobile());
        } catch (IllegalArgumentException exception) {
            throw new IllegalStateException(exception.getMessage());
        }
        return queue(patient, null, null, MessageType.MANUAL, content,
                scheduledFor == null ? Instant.now() : scheduledFor, null, List.of(), actorId);
    }

    @Transactional
    public void cancelPendingAppointmentMessages(Long appointmentId) {
        messages.findAllByAppointmentIdAndEstado(appointmentId, MessageStatus.PENDIENTE)
                .forEach(WhatsAppMessage::cancel);
    }

    @Transactional(readOnly = true)
    public boolean hasActiveAppointmentMessage(Long appointmentId, MessageType type) {
        return messages.existsByAppointmentIdAndTipoAndEstadoIn(appointmentId, type, ACTIVE);
    }

    @Scheduled(fixedDelayString = "${app.whatsapp.outbox-delay-ms:30000}")
    @Transactional
    public void dispatch() {
        for (WhatsAppMessage message : messages
                .findTop25ByEstadoAndScheduledForLessThanEqualOrderByScheduledForAsc(MessageStatus.PENDIENTE, Instant.now())) {
            WhatsAppConversation conversation = conversations.findById(message.getConversationId()).orElse(null);
            if (conversation == null) {
                message.failed("Conversación no encontrada");
                continue;
            }
            message.registerAttempt();
            WhatsAppGateway.GatewayResult result = gateway.send(conversation.getPhone(), message);
            if (result.sent()) {
                message.sent(result.providerId());
                markRelatedRecord(message);
            } else if (result.retryable() && message.canRetry()) {
                message.retry(result.error(), Instant.now().plusSeconds(backoffSeconds(message.getAttempts())));
            } else {
                message.failed(result.error());
            }
        }
    }

    private WhatsAppMessage queue(Patient patient, Long appointmentId, Long encounterId, MessageType type,
                                  String content, Instant scheduledFor, String templateName,
                                  List<String> parameters, Long actorId) {
        String phone = phoneNumbers.outbound(patient.getMobile());
        WhatsAppConversation conversation = conversations
                .findFirstByTelefonoAndEstadoNot(phone, ConversationStatus.CERRADA)
                .orElseGet(() -> conversations.save(new WhatsAppConversation(patient.getId(), phone)));
        conversation.touch();
        return messages.save(WhatsAppMessage.outgoing(conversation.getId(), patient.getId(), appointmentId,
                encounterId, type, content, scheduledFor, templateName, json(parameters), maxAttempts, actorId));
    }

    private void markRelatedRecord(WhatsAppMessage message) {
        followUps.findByMessageId(message.getId()).ifPresent(PostConsultationFollowUp::markSent);
        if (message.getAppointmentId() == null) return;
        appointments.findById(message.getAppointmentId()).ifPresent(appointment -> {
            if (message.getType() == MessageType.CITA_CONFIRMACION) appointment.markConfirmationSent();
            if (message.getType() == MessageType.CITA_RECORDATORIO) appointment.markReminderSent();
        });
    }

    private boolean canMessage(Patient patient) {
        if (patient.getMobile() == null || !patient.isWhatsAppConsent()) return false;
        try {
            phoneNumbers.outbound(patient.getMobile());
            return true;
        } catch (IllegalArgumentException exception) {
            return false;
        }
    }

    private String json(List<String> values) {
        try {
            return mapper.writeValueAsString(values);
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("No se pudieron preparar los parámetros del mensaje", exception);
        }
    }

    private long backoffSeconds(int attempts) {
        return switch (attempts) {
            case 1 -> 60;
            case 2 -> 300;
            default -> 1800;
        };
    }
}
