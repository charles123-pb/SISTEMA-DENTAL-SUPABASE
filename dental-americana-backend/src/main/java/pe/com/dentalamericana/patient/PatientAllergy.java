package pe.com.dentalamericana.patient;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "paciente_alergias")
public class PatientAllergy {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Column(nullable = false, length = 150) private String sustancia;
    @Column(length = 300) private String reaccion;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private AllergySeverity severidad;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private AllergyStatus estado;
    @Column(length = 1000) private String observacion;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Version @Column(nullable = false) private Long version;

    protected PatientAllergy() {}
    public PatientAllergy(Long patientId, String substance, String reaction, AllergySeverity severity,
                          AllergyStatus status, String observation, Long actorId) {
        this.patientId = patientId; this.sustancia = substance; this.reaccion = reaction;
        this.severidad = severity; this.estado = status; this.observacion = observation; this.createdBy = actorId;
    }
    @PrePersist void onCreate() { createdAt = Instant.now(); }
    public Long getId() { return id; } public String getSubstance() { return sustancia; }
    public String getReaction() { return reaccion; } public AllergySeverity getSeverity() { return severidad; }
    public AllergyStatus getStatus() { return estado; } public String getObservation() { return observacion; }
    public boolean isActive() { return activo; } public Instant getCreatedAt() { return createdAt; }
}
