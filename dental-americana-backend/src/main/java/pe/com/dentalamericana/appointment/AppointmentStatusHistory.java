package pe.com.dentalamericana.appointment;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "cita_historial_estados")
public class AppointmentStatusHistory {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "cita_id", nullable = false) private Long appointmentId;
    @Enumerated(EnumType.STRING) @Column(name = "estado_anterior", length = 30) private AppointmentStatus previousStatus;
    @Enumerated(EnumType.STRING) @Column(name = "estado_nuevo", nullable = false, length = 30) private AppointmentStatus newStatus;
    @Column(length = 500) private String motivo;
    @Column(name = "creado_por", nullable = false) private Long createdBy;
    @Column(name = "creado_en", nullable = false, insertable = false, updatable = false) private Instant createdAt;

    protected AppointmentStatusHistory() {}
    public AppointmentStatusHistory(Long appointmentId, AppointmentStatus previousStatus, AppointmentStatus newStatus,
                                    String reason, Long actorId) {
        this.appointmentId = appointmentId; this.previousStatus = previousStatus; this.newStatus = newStatus;
        this.motivo = reason; this.createdBy = actorId;
    }
}
