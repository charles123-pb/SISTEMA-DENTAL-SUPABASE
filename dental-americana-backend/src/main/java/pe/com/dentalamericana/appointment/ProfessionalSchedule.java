package pe.com.dentalamericana.appointment;

import jakarta.persistence.*;
import java.time.LocalTime;

@Entity
@Table(name = "horarios_profesionales")
public class ProfessionalSchedule {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "profesional_id", nullable = false) private Long professionalId;
    @Column(name = "dia_semana", nullable = false) private int dayOfWeek;
    @Column(name = "hora_inicio", nullable = false) private LocalTime startTime;
    @Column(name = "hora_fin", nullable = false) private LocalTime endTime;
    @Column(name = "intervalo_minutos", nullable = false) private int intervalMinutes;
    @Column(nullable = false) private boolean activo = true;
    @Version @Column(nullable = false) private Long version;

    protected ProfessionalSchedule() {}
    public Long getId() { return id; }
    public Long getProfessionalId() { return professionalId; }
    public int getDayOfWeek() { return dayOfWeek; }
    public LocalTime getStartTime() { return startTime; }
    public LocalTime getEndTime() { return endTime; }
    public int getIntervalMinutes() { return intervalMinutes; }
    public boolean isActive() { return activo; }
}
