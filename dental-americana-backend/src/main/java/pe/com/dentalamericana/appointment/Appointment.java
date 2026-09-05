package pe.com.dentalamericana.appointment;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "citas")
public class Appointment {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Column(name = "profesional_id", nullable = false) private Long professionalId;
    @Column(name = "tipo_cita_id", nullable = false) private Long appointmentTypeId;
    @Column(nullable = false) private Instant inicio;
    @Column(nullable = false) private Instant fin;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private AppointmentStatus estado;
    @Column(nullable = false, length = 500) private String motivo;
    @Column(length = 1000) private String notas;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private AppointmentSource origen;
    @Column(name = "motivo_cancelacion", length = 500) private String cancellationReason;
    @Column(name = "confirmacion_enviada", nullable = false) private boolean confirmationSent;
    @Column(name = "recordatorio_programado", nullable = false) private boolean reminderScheduled;
    @Column(name = "recordatorio_enviado", nullable = false) private boolean reminderSent;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Column(name = "actualizado_por", nullable = false) private Long updatedBy;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "actualizado_en", nullable = false) private Instant updatedAt;
    @Version @Column(nullable = false) private Long version;

    protected Appointment() {}
    public Appointment(Long patientId, Long professionalId, Long appointmentTypeId, Instant start, Instant end,
                       String reason, String notes, AppointmentSource source, Long actorId) {
        this.patientId = patientId; this.professionalId = professionalId; this.appointmentTypeId = appointmentTypeId;
        this.inicio = start; this.fin = end; this.motivo = reason; this.notas = notes; this.origen = source;
        this.estado = AppointmentStatus.PENDIENTE_CONFIRMACION; this.createdBy = actorId; this.updatedBy = actorId;
    }
    public void reschedule(Long professionalId, Long appointmentTypeId, Instant start, Instant end,
                           String reason, String notes, Long actorId) {
        this.professionalId = professionalId; this.appointmentTypeId = appointmentTypeId; this.inicio = start;
        this.fin = end; this.motivo = reason; this.notas = notes; this.updatedBy = actorId;
        this.confirmationSent = false; this.reminderScheduled = false; this.reminderSent = false;
        if (estado == AppointmentStatus.CONFIRMADA) estado = AppointmentStatus.PENDIENTE_CONFIRMACION;
    }
    public void changeStatus(AppointmentStatus status, String cancellationReason, Long actorId) {
        this.estado = status; this.cancellationReason = cancellationReason; this.updatedBy = actorId;
    }
    public void markConfirmationSent() { this.confirmationSent = true; }
    public void markReminderQueued(Long actorId) { this.reminderScheduled = true; this.updatedBy = actorId; }
    public void markReminderSent() { this.reminderSent = true; }
    @PrePersist void onCreate() { Instant now = Instant.now(); createdAt = now; updatedAt = now; }
    @PreUpdate void onUpdate() { updatedAt = Instant.now(); }

    public Long getId() { return id; }
    public Long getPatientId() { return patientId; }
    public Long getProfessionalId() { return professionalId; }
    public Long getAppointmentTypeId() { return appointmentTypeId; }
    public Instant getStart() { return inicio; }
    public Instant getEnd() { return fin; }
    public AppointmentStatus getStatus() { return estado; }
    public String getReason() { return motivo; }
    public String getNotes() { return notas; }
    public AppointmentSource getSource() { return origen; }
    public String getCancellationReason() { return cancellationReason; }
    public boolean isConfirmationSent() { return confirmationSent; }
    public boolean isReminderScheduled() { return reminderScheduled; }
    public boolean isReminderSent() { return reminderSent; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getVersion() { return version; }
    public Long getUpdatedBy() { return updatedBy; }
}
