package pe.com.dentalamericana.appointment;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "bloqueos_agenda")
public class ScheduleBlock {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "profesional_id", nullable = false) private Long professionalId;
    @Column(nullable = false) private Instant inicio;
    @Column(nullable = false) private Instant fin;
    @Column(nullable = false, length = 250) private String motivo;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_por", nullable = false) private Long createdBy;
    @Column(name = "creado_en", nullable = false, insertable = false, updatable = false) private Instant createdAt;

    protected ScheduleBlock() {}
    public ScheduleBlock(Long professionalId, Instant start, Instant end, String reason, Long actorId) {
        this.professionalId = professionalId; this.inicio = start; this.fin = end;
        this.motivo = reason; this.createdBy = actorId;
    }
    public Long getId() { return id; }
    public Long getProfessionalId() { return professionalId; }
    public Instant getStart() { return inicio; }
    public Instant getEnd() { return fin; }
    public String getReason() { return motivo; }
}
