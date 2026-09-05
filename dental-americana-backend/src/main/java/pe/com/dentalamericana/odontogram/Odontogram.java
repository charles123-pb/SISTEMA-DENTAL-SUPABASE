package pe.com.dentalamericana.odontogram;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name = "odontogramas")
public class Odontogram {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "atencion_id", nullable = false) private Long encounterId;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Enumerated(EnumType.STRING) @Column(name = "tipo_denticion", nullable = false, length = 20) private DentitionType dentitionType;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private OdontogramStatus estado;
    @Column(name = "observacion_general", columnDefinition = "TEXT") private String generalObservation;
    @Column(name = "aprobado_por") private Long approvedBy;
    @Column(name = "aprobado_en") private Instant approvedAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Column(name = "actualizado_por", nullable = false) private Long updatedBy;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "actualizado_en", nullable = false) private Instant updatedAt;
    @Version @Column(nullable = false) private Long version;
    protected Odontogram() {}
    public Odontogram(Long encounterId, Long patientId, DentitionType type, Long actorId) { this.encounterId = encounterId; this.patientId = patientId; this.dentitionType = type; this.estado = OdontogramStatus.BORRADOR; this.createdBy = actorId; this.updatedBy = actorId; }
    public void observe(String observation, Long actorId) { this.generalObservation = observation; this.updatedBy = actorId; }
    public void touch(Long actorId) { this.updatedBy = actorId; this.updatedAt = Instant.now(); }
    public void approve(Long actorId) { this.estado = OdontogramStatus.APROBADO; this.approvedBy = actorId; this.approvedAt = Instant.now(); this.updatedBy = actorId; }
    @PrePersist void create() { Instant now = Instant.now(); createdAt = now; updatedAt = now; }
    @PreUpdate void update() { updatedAt = Instant.now(); }
    public Long getId(){return id;} public Long getEncounterId(){return encounterId;} public Long getPatientId(){return patientId;}
    public DentitionType getDentitionType(){return dentitionType;} public OdontogramStatus getStatus(){return estado;}
    public String getGeneralObservation(){return generalObservation;} public Long getApprovedBy(){return approvedBy;}
    public Instant getApprovedAt(){return approvedAt;} public Instant getCreatedAt(){return createdAt;}
    public Instant getUpdatedAt(){return updatedAt;} public Long getVersion(){return version;}
}
