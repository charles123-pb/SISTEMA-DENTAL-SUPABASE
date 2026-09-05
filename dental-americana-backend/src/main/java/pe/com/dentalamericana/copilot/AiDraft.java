package pe.com.dentalamericana.copilot;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.Instant;

@Entity @Table(name="borradores_ia")
public class AiDraft {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="atencion_id",nullable=false) private Long encounterId;
    @Column(name="paciente_id",nullable=false) private Long patientId;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=40) private AiDraftType tipo;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=20) private AiDraftStatus estado;
    @Column(nullable=false,columnDefinition="TEXT") private String contenido;
    @JdbcTypeCode(SqlTypes.JSON) @Column(name="datos_fuente",nullable=false,columnDefinition="jsonb") private String sourceData;
    @JdbcTypeCode(SqlTypes.JSON) @Column(name="campos_faltantes",nullable=false,columnDefinition="jsonb") private String missingFields;
    @Column(nullable=false,length=500) private String advertencia;
    @Column(name="motivo_rechazo",length=500) private String rejectionReason;
    @Column(name="generado_por",nullable=false) private Long generatedBy;
    @Column(name="generado_en",nullable=false) private Instant generatedAt;
    @Column(name="revisado_por") private Long reviewedBy;
    @Column(name="revisado_en") private Instant reviewedAt;
    @Version private Long version;
    protected AiDraft() {}
    public AiDraft(Long encounterId,Long patientId,AiDraftType type,String content,String sourceData,String missingFields,String warning,Long actor){this.encounterId=encounterId;this.patientId=patientId;this.tipo=type;this.estado=AiDraftStatus.BORRADOR;this.contenido=content;this.sourceData=sourceData;this.missingFields=missingFields;this.advertencia=warning;this.generatedBy=actor;}
    public void approve(Long actor){requireDraft();estado=AiDraftStatus.APROBADO;reviewedBy=actor;reviewedAt=Instant.now();}
    public void reject(Long actor,String reason){requireDraft();estado=AiDraftStatus.RECHAZADO;rejectionReason=reason;reviewedBy=actor;reviewedAt=Instant.now();}
    private void requireDraft(){if(estado!=AiDraftStatus.BORRADOR)throw new IllegalStateException("El borrador ya fue revisado");}
    @PrePersist void create(){generatedAt=Instant.now();}
    public Long getId(){return id;} public Long getEncounterId(){return encounterId;} public Long getPatientId(){return patientId;} public AiDraftType getType(){return tipo;} public AiDraftStatus getStatus(){return estado;} public String getContent(){return contenido;} public String getSourceData(){return sourceData;} public String getMissingFields(){return missingFields;} public String getWarning(){return advertencia;} public String getRejectionReason(){return rejectionReason;} public Long getGeneratedBy(){return generatedBy;} public Instant getGeneratedAt(){return generatedAt;} public Long getReviewedBy(){return reviewedBy;} public Instant getReviewedAt(){return reviewedAt;} public Long getVersion(){return version;}
}
