package pe.com.dentalamericana.messaging;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "seguimientos_postconsulta")
public class PostConsultationFollowUp {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Column(name = "atencion_id", nullable = false) private Long encounterId;
    @Column(name = "mensaje_id") private Long messageId;
    @Column(name = "programado_para", nullable = false) private Instant scheduledFor;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private FollowUpStatus estado;
    @Column(columnDefinition = "TEXT") private String respuesta;
    private String clasificacion;
    @Column(name = "motivo_alerta") private String alertReason;
    @Column(name = "revisado_por") private Long reviewedBy;
    @Column(name = "revisado_en") private Instant reviewedAt;
    @Column(name = "creado_por", nullable = false) private Long createdBy;
    @Column(name = "creado_en", nullable = false) private Instant createdAt;
    @Column(name = "actualizado_en", nullable = false) private Instant updatedAt;
    @Version private Long version;

    protected PostConsultationFollowUp() {}

    public PostConsultationFollowUp(Long patientId, Long encounterId, Instant scheduledFor, Long actorId) {
        this.patientId = patientId;
        this.encounterId = encounterId;
        this.scheduledFor = scheduledFor;
        this.estado = FollowUpStatus.PROGRAMADO;
        this.createdBy = actorId;
    }

    public void attachMessage(Long id) { messageId = id; }
    public void markSent() { if (estado == FollowUpStatus.PROGRAMADO) estado = FollowUpStatus.ENVIADO; }
    public void closeWithoutMessage(String reason) {
        estado = FollowUpStatus.CERRADO;
        clasificacion = reason;
    }
    public void respond(String response, String classification, String alert) {
        respuesta = response;
        clasificacion = classification;
        alertReason = alert;
        estado = alert == null ? FollowUpStatus.RESPONDIDO : FollowUpStatus.ALERTA;
    }
    public void review(Long actorId) {
        reviewedBy = actorId;
        reviewedAt = Instant.now();
        estado = FollowUpStatus.REVISADO;
    }

    @PrePersist void create() { Instant now = Instant.now(); createdAt = now; updatedAt = now; }
    @PreUpdate void update() { updatedAt = Instant.now(); }

    public Long getId() { return id; }
    public Long getPatientId() { return patientId; }
    public Long getEncounterId() { return encounterId; }
    public Long getMessageId() { return messageId; }
    public Instant getScheduledFor() { return scheduledFor; }
    public FollowUpStatus getStatus() { return estado; }
    public String getResponse() { return respuesta; }
    public String getClassification() { return clasificacion; }
    public String getAlertReason() { return alertReason; }
    public Long getReviewedBy() { return reviewedBy; }
    public Instant getReviewedAt() { return reviewedAt; }
    public Long getVersion() { return version; }
}
