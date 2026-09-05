package pe.com.dentalamericana.patient;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "paciente_medicamentos")
public class PatientMedication {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Column(nullable = false, length = 180) private String medicamento;
    @Column(length = 100) private String dosis;
    @Column(length = 100) private String frecuencia;
    @Column(length = 250) private String motivo;
    @Column(name = "fecha_inicio") private LocalDate startDate;
    @Column(name = "fecha_fin") private LocalDate endDate;
    @Column(nullable = false) private boolean vigente = true;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Version @Column(nullable = false) private Long version;

    protected PatientMedication() {}
    public PatientMedication(Long patientId, String medication, String dose, String frequency, String reason,
                             LocalDate startDate, LocalDate endDate, boolean current, Long actorId) {
        this.patientId = patientId; this.medicamento = medication; this.dosis = dose; this.frecuencia = frequency;
        this.motivo = reason; this.startDate = startDate; this.endDate = endDate; this.vigente = current; this.createdBy = actorId;
    }
    @PrePersist void onCreate() { createdAt = Instant.now(); }
    public Long getId() { return id; } public String getMedication() { return medicamento; }
    public String getDose() { return dosis; } public String getFrequency() { return frecuencia; }
    public String getReason() { return motivo; } public LocalDate getStartDate() { return startDate; }
    public LocalDate getEndDate() { return endDate; } public boolean isCurrent() { return vigente; }
    public boolean isActive() { return activo; } public Instant getCreatedAt() { return createdAt; }
}
