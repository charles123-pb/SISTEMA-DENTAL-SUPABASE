package pe.com.dentalamericana.patient;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "paciente_archivos")
public class PatientFile {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 30) private PatientFileCategory categoria;
    @Column(name = "nombre_original", nullable = false, length = 255) private String originalName;
    @Column(name = "nombre_interno", nullable = false, unique = true, length = 255) private String internalName;
    @Column(name = "tipo_contenido", nullable = false, length = 100) private String contentType;
    @Column(name = "tamano_bytes", nullable = false) private long sizeBytes;
    @Column(nullable = false, length = 500) private String ubicacion;
    @Column(length = 300) private String descripcion;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;

    protected PatientFile() {}
    public PatientFile(Long patientId, PatientFileCategory category, String originalName, String internalName,
                       String contentType, long sizeBytes, String location, String description, Long actorId) {
        this.patientId = patientId; this.categoria = category; this.originalName = originalName;
        this.internalName = internalName; this.contentType = contentType; this.sizeBytes = sizeBytes;
        this.ubicacion = location; this.descripcion = description; this.createdBy = actorId;
    }
    @PrePersist void onCreate() { createdAt = Instant.now(); }
    public Long getId() { return id; } public Long getPatientId() { return patientId; }
    public PatientFileCategory getCategory() { return categoria; } public String getOriginalName() { return originalName; }
    public String getInternalName() { return internalName; } public String getContentType() { return contentType; }
    public long getSizeBytes() { return sizeBytes; } public String getLocation() { return ubicacion; }
    public String getDescription() { return descripcion; } public boolean isActive() { return activo; }
    public Instant getCreatedAt() { return createdAt; }
}
