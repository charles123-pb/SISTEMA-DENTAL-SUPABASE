package pe.com.dentalamericana.patient;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "paciente_contactos_emergencia")
public class EmergencyContact {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Column(name = "nombre_completo", nullable = false, length = 150) private String fullName;
    @Column(nullable = false, length = 60) private String parentesco;
    @Column(nullable = false, length = 20) private String telefono;
    @Column(nullable = false) private boolean principal;
    @Column(nullable = false) private boolean activo = true;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;

    protected EmergencyContact() {}
    public EmergencyContact(Long patientId, String fullName, String relationship, String phone, boolean primary, Long actorId) {
        this.patientId = patientId; this.fullName = fullName; this.parentesco = relationship;
        this.telefono = phone; this.principal = primary; this.createdBy = actorId;
    }
    @PrePersist void onCreate() { createdAt = Instant.now(); }
    public Long getId() { return id; } public Long getPatientId() { return patientId; }
    public String getFullName() { return fullName; } public String getRelationship() { return parentesco; }
    public String getPhone() { return telefono; } public boolean isPrimary() { return principal; }
    public boolean isActive() { return activo; } public Instant getCreatedAt() { return createdAt; }
}
