package pe.com.dentalamericana.messaging;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;

@Entity
@Table(name = "mensajes_whatsapp")
public class WhatsAppMessage {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "conversacion_id", nullable = false) private Long conversationId;
    @Column(name = "paciente_id") private Long patientId;
    @Column(name = "cita_id") private Long appointmentId;
    @Column(name = "atencion_id") private Long encounterId;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 10) private MessageDirection direccion;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 40) private MessageType tipo;
    @Column(nullable = false, columnDefinition = "TEXT") private String contenido;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private MessageStatus estado;
    @Column(name = "programado_para") private Instant scheduledFor;
    @Column(name = "proveedor_id", length = 150) private String providerId;
    @Column(name = "plantilla_nombre", length = 120) private String templateName;
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "parametros_plantilla", nullable = false, columnDefinition = "jsonb")
    private String templateParameters;
    private String intencion;
    @Column(name = "requiere_revision", nullable = false) private boolean reviewRequired;
    @Column(name = "error_detalle", length = 500) private String errorDetail;
    @Column(nullable = false) private int intentos;
    @Column(name = "max_intentos", nullable = false) private int maxAttempts;
    @Column(name = "ultimo_intento_en") private Instant lastAttemptAt;
    @Column(name = "creado_por") private Long createdBy;
    @Column(name = "creado_en", nullable = false) private Instant createdAt;
    @Column(name = "enviado_en") private Instant sentAt;

    protected WhatsAppMessage() {}

    public static WhatsAppMessage outgoing(Long conversationId, Long patientId, Long appointmentId,
                                            Long encounterId, MessageType type, String content,
                                            Instant scheduledFor, String templateName,
                                            String templateParameters, int maxAttempts, Long actorId) {
        WhatsAppMessage message = new WhatsAppMessage();
        message.conversationId = conversationId;
        message.patientId = patientId;
        message.appointmentId = appointmentId;
        message.encounterId = encounterId;
        message.direccion = MessageDirection.SALIENTE;
        message.tipo = type;
        message.contenido = content;
        message.estado = MessageStatus.PENDIENTE;
        message.scheduledFor = scheduledFor;
        message.templateName = blankToNull(templateName);
        message.templateParameters = templateParameters == null ? "[]" : templateParameters;
        message.maxAttempts = Math.max(1, Math.min(maxAttempts, 10));
        message.createdBy = actorId;
        return message;
    }

    public static WhatsAppMessage incoming(Long conversationId, Long patientId, String providerId,
                                            String content, String intent, boolean reviewRequired) {
        WhatsAppMessage message = new WhatsAppMessage();
        message.conversationId = conversationId;
        message.patientId = patientId;
        message.direccion = MessageDirection.ENTRANTE;
        message.tipo = MessageType.ENTRANTE;
        message.contenido = content;
        message.estado = MessageStatus.RECIBIDO;
        message.providerId = providerId;
        message.templateParameters = "[]";
        message.intencion = intent;
        message.reviewRequired = reviewRequired;
        message.maxAttempts = 1;
        return message;
    }

    public void registerAttempt() {
        if (estado != MessageStatus.PENDIENTE) throw new IllegalStateException("El mensaje no está pendiente");
        intentos++;
        lastAttemptAt = Instant.now();
    }

    public void sent(String providerId) {
        estado = MessageStatus.ENVIADO;
        this.providerId = providerId;
        sentAt = Instant.now();
        errorDetail = null;
    }

    public void retry(String error, Instant nextAttempt) {
        estado = MessageStatus.PENDIENTE;
        errorDetail = limit(error);
        scheduledFor = nextAttempt;
    }

    public void failed(String error) { estado = MessageStatus.FALLIDO; errorDetail = limit(error); }
    public void cancel() { if (estado == MessageStatus.PENDIENTE) estado = MessageStatus.CANCELADO; }

    public void providerStatus(MessageStatus status, String error) {
        if (status == MessageStatus.FALLIDO) { failed(error); return; }
        if (status == MessageStatus.LEIDO
                || status == MessageStatus.ENTREGADO && estado != MessageStatus.LEIDO
                || status == MessageStatus.ENVIADO && estado == MessageStatus.PENDIENTE) estado = status;
    }

    public boolean canRetry() { return intentos < maxAttempts; }

    @PrePersist void create() {
        createdAt = Instant.now();
        if (templateParameters == null) templateParameters = "[]";
        if (maxAttempts == 0) maxAttempts = 1;
    }

    private static String blankToNull(String value) { return value == null || value.isBlank() ? null : value.trim(); }
    private static String limit(String value) {
        if (value == null || value.isBlank()) return "Error de proveedor sin detalle";
        String clean = value.trim();
        return clean.length() <= 500 ? clean : clean.substring(0, 500);
    }

    public Long getId() { return id; }
    public Long getConversationId() { return conversationId; }
    public Long getPatientId() { return patientId; }
    public Long getAppointmentId() { return appointmentId; }
    public Long getEncounterId() { return encounterId; }
    public MessageDirection getDirection() { return direccion; }
    public MessageType getType() { return tipo; }
    public String getContent() { return contenido; }
    public MessageStatus getStatus() { return estado; }
    public Instant getScheduledFor() { return scheduledFor; }
    public String getProviderId() { return providerId; }
    public String getTemplateName() { return templateName; }
    public String getTemplateParameters() { return templateParameters; }
    public String getIntent() { return intencion; }
    public boolean isReviewRequired() { return reviewRequired; }
    public String getErrorDetail() { return errorDetail; }
    public int getAttempts() { return intentos; }
    public int getMaxAttempts() { return maxAttempts; }
    public Instant getLastAttemptAt() { return lastAttemptAt; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getSentAt() { return sentAt; }
}
