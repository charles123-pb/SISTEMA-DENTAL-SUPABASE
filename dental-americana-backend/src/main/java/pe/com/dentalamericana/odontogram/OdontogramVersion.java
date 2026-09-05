package pe.com.dentalamericana.odontogram;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;

@Entity
@Table(name = "odontograma_versiones")
public class OdontogramVersion {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "odontograma_id", nullable = false)
    private Long odontogramId;

    @Column(name = "numero_version", nullable = false)
    private Long versionNumber;

    @Column(nullable = false, length = 500)
    private String resumen;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false, columnDefinition = "jsonb")
    private String datos;

    @Column(name = "creado_por", nullable = false)
    private Long createdBy;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private Instant createdAt;

    protected OdontogramVersion() {}

    public OdontogramVersion(Long odontogramId, Long versionNumber, String summary,
                             String data, Long actorId) {
        this.odontogramId = odontogramId;
        this.versionNumber = versionNumber;
        this.resumen = summary;
        this.datos = data;
        this.createdBy = actorId;
    }

    @PrePersist
    void onCreate() { createdAt = Instant.now(); }

    public Long getVersionNumber() { return versionNumber; }
}
