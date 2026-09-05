package pe.com.dentalamericana.clinical;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.Instant;

@Entity
@Table(name = "atencion_versiones")
public class ClinicalEncounterVersion {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "atencion_id", nullable = false) private Long encounterId;
    @Column(name = "numero_version", nullable = false) private Long versionNumber;
    @Column(nullable = false, length = 30) private String accion;
    @Column(columnDefinition = "TEXT") private String resumen;
    @JdbcTypeCode(SqlTypes.JSON) @Column(nullable = false, columnDefinition = "jsonb") private String datos;
    @Column(name = "creado_por", nullable = false) private Long createdBy;
    @Column(name = "creado_en", nullable = false, insertable = false, updatable = false) private Instant createdAt;
    protected ClinicalEncounterVersion() {}
    public ClinicalEncounterVersion(Long encounterId, Long versionNumber, String action, String summary, String data, Long actorId) {
        this.encounterId = encounterId; this.versionNumber = versionNumber; this.accion = action;
        this.resumen = summary; this.datos = data; this.createdBy = actorId;
    }
}
