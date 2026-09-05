package pe.com.dentalamericana.patient;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "paciente_antecedentes")
public class PatientHistory {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private HistoryType tipo;
    @Column(nullable = false, length = 500) private String descripcion;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private HistoryStatus estado;
    @Column(length = 1000) private String observacion;
    @Column(name = "fecha_informada") private LocalDate reportedDate;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Version @Column(nullable = false) private Long version;

    protected PatientHistory() {}
    public PatientHistory(Long patientId, HistoryType type, String description, HistoryStatus status,
                          String observation, LocalDate reportedDate, Long actorId) {
        this.patientId = patientId; this.tipo = type; this.descripcion = description; this.estado = status;
        this.observacion = observation; this.reportedDate = reportedDate; this.createdBy = actorId;
    }
    @PrePersist void onCreate() { createdAt = Instant.now(); }
    public Long getId() { return id; } public HistoryType getType() { return tipo; }
    public String getDescription() { return descripcion; } public HistoryStatus getStatus() { return estado; }
    public String getObservation() { return observacion; } public LocalDate getReportedDate() { return reportedDate; }
    public boolean isActive() { return activo; } public Instant getCreatedAt() { return createdAt; }
}
