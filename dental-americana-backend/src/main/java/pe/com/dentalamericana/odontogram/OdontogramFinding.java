package pe.com.dentalamericana.odontogram;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name = "odontograma_hallazgos")
public class OdontogramFinding {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "odontograma_id", nullable = false) private Long odontogramId;
    @Column(nullable = false, length = 3) private String pieza;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private ToothSurface superficie;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 40) private ToothCondition condicion;
    @Enumerated(EnumType.STRING) @Column(name = "estado_tratamiento", nullable = false, length = 20) private TreatmentState treatmentState;
    @Column(length = 500) private String observacion;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Column(name = "actualizado_por", nullable = false) private Long updatedBy;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "actualizado_en", nullable = false) private Instant updatedAt;
    @Version @Column(nullable = false) private Long version;
    protected OdontogramFinding() {}
    public OdontogramFinding(Long odontogramId, String tooth, ToothSurface surface, ToothCondition condition,
                             TreatmentState state, String observation, Long actorId) { this.odontogramId=odontogramId; this.pieza=tooth; this.superficie=surface; this.condicion=condition; this.treatmentState=state; this.observacion=observation; this.createdBy=actorId; this.updatedBy=actorId; }
    public void revise(TreatmentState state, String observation, Long actorId){this.treatmentState=state;this.observacion=observation;this.updatedBy=actorId;}
    public void deactivate(Long actorId){this.activo=false;this.updatedBy=actorId;}
    @PrePersist void create(){Instant now=Instant.now();createdAt=now;updatedAt=now;} @PreUpdate void update(){updatedAt=Instant.now();}
    public Long getId(){return id;} public Long getOdontogramId(){return odontogramId;} public String getTooth(){return pieza;}
    public ToothSurface getSurface(){return superficie;} public ToothCondition getCondition(){return condicion;}
    public TreatmentState getTreatmentState(){return treatmentState;} public String getObservation(){return observacion;}
    public Instant getCreatedAt(){return createdAt;} public Instant getUpdatedAt(){return updatedAt;} public Long getVersion(){return version;}
}
