package pe.com.dentalamericana.patient;

import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "pacientes")
public class Patient {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "numero_historia", nullable = false, unique = true, length = 20)
    private String historyNumber;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_documento", nullable = false, length = 20)
    private DocumentType documentType;

    @Column(name = "numero_documento", length = 20)
    private String documentNumber;

    @Column(name = "nombres", nullable = false, length = 100)
    private String firstNames;

    @Column(name = "apellido_paterno", nullable = false, length = 80)
    private String paternalSurname;

    @Column(name = "apellido_materno", length = 80)
    private String maternalSurname;

    @Column(name = "fecha_nacimiento", nullable = false)
    private LocalDate birthDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "sexo", nullable = false, length = 20)
    private Sex sex;

    @Column(name = "lugar_nacimiento", length = 150)
    private String birthPlace;

    @Column(length = 120)
    private String ocupacion;

    @Column(name = "estado_civil", length = 30)
    private String maritalStatus;

    @Column(name = "grado_instruccion", length = 60)
    private String educationLevel;

    @Column(length = 80)
    private String religion;

    @Column(name = "autoidentificacion_etnica", length = 100)
    private String ethnicSelfIdentification;

    @Column(length = 20)
    private String celular;

    @Column(length = 20)
    private String telefono;

    @Column(name = "whatsapp_autorizado", nullable = false)
    private boolean whatsappConsent;

    @Column(name = "whatsapp_autorizado_en")
    private Instant whatsappConsentAt;

    @Column(name = "whatsapp_autorizado_por")
    private Long whatsappConsentBy;

    @Column(name = "whatsapp_revocado_en")
    private Instant whatsappRevokedAt;

    @Column(length = 150)
    private String email;

    @Column(length = 250)
    private String direccion;

    @Column(name = "responsable_nombre", length = 150)
    private String responsibleName;

    @Column(name = "responsable_documento", length = 20)
    private String responsibleDocument;

    @Column(name = "responsable_parentesco", length = 60)
    private String responsibleRelationship;

    @Column(name = "responsable_telefono", length = 20)
    private String responsiblePhone;

    @Column(name = "activo", nullable = false)
    private boolean active = true;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "actualizado_en", nullable = false)
    private Instant updatedAt;

    @Column(name = "creado_por", nullable = false, updatable = false)
    private Long createdBy;

    @Column(name = "actualizado_por", nullable = false)
    private Long updatedBy;

    @Version
    @Column(nullable = false)
    private Long version;

    protected Patient() {}

    public Patient(String historyNumber, Long actorId) {
        this.historyNumber = historyNumber;
        this.createdBy = actorId;
        this.updatedBy = actorId;
    }

    public void updateIdentity(DocumentType documentType, String documentNumber, String firstNames,
                               String paternalSurname, String maternalSurname, LocalDate birthDate, Sex sex) {
        this.documentType = documentType;
        this.documentNumber = documentNumber;
        this.firstNames = firstNames;
        this.paternalSurname = paternalSurname;
        this.maternalSurname = maternalSurname;
        this.birthDate = birthDate;
        this.sex = sex;
    }

    public void updateAdditional(String birthPlace, String occupation, String maritalStatus,
                                 String educationLevel, String religion, String ethnicSelfIdentification) {
        this.birthPlace = birthPlace;
        this.ocupacion = occupation;
        this.maritalStatus = maritalStatus;
        this.educationLevel = educationLevel;
        this.religion = religion;
        this.ethnicSelfIdentification = ethnicSelfIdentification;
    }

    public void updateContact(String mobile, String phone, String email, String address) {
        this.celular = mobile;
        this.telefono = phone;
        this.email = email;
        this.direccion = address;
    }

    public void updateWhatsAppConsent(boolean authorized, Long actorId) {
        if (authorized && !whatsappConsent) {
            whatsappConsentAt = Instant.now();
            whatsappConsentBy = actorId;
            whatsappRevokedAt = null;
        } else if (!authorized && whatsappConsent) {
            whatsappRevokedAt = Instant.now();
        }
        whatsappConsent = authorized;
    }

    public void updateResponsible(String name, String document, String relationship, String phone) {
        this.responsibleName = name;
        this.responsibleDocument = document;
        this.responsibleRelationship = relationship;
        this.responsiblePhone = phone;
    }

    public void changeActive(boolean active, Long actorId) { this.active = active; this.updatedBy = actorId; }
    public void markUpdatedBy(Long actorId) { this.updatedBy = actorId; }

    @PrePersist
    void onCreate() { Instant now = Instant.now(); createdAt = now; updatedAt = now; }

    @PreUpdate
    void onUpdate() { updatedAt = Instant.now(); }

    public Long getId() { return id; }
    public String getHistoryNumber() { return historyNumber; }
    public DocumentType getDocumentType() { return documentType; }
    public String getDocumentNumber() { return documentNumber; }
    public String getFirstNames() { return firstNames; }
    public String getPaternalSurname() { return paternalSurname; }
    public String getMaternalSurname() { return maternalSurname; }
    public LocalDate getBirthDate() { return birthDate; }
    public Sex getSex() { return sex; }
    public String getBirthPlace() { return birthPlace; }
    public String getOccupation() { return ocupacion; }
    public String getMaritalStatus() { return maritalStatus; }
    public String getEducationLevel() { return educationLevel; }
    public String getReligion() { return religion; }
    public String getEthnicSelfIdentification() { return ethnicSelfIdentification; }
    public String getMobile() { return celular; }
    public String getPhone() { return telefono; }
    public boolean isWhatsAppConsent() { return whatsappConsent; }
    public Instant getWhatsAppConsentAt() { return whatsappConsentAt; }
    public Long getWhatsAppConsentBy() { return whatsappConsentBy; }
    public Instant getWhatsAppRevokedAt() { return whatsappRevokedAt; }
    public String getEmail() { return email; }
    public String getAddress() { return direccion; }
    public String getResponsibleName() { return responsibleName; }
    public String getResponsibleDocument() { return responsibleDocument; }
    public String getResponsibleRelationship() { return responsibleRelationship; }
    public String getResponsiblePhone() { return responsiblePhone; }
    public boolean isActive() { return active; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getCreatedBy() { return createdBy; }
    public Long getUpdatedBy() { return updatedBy; }
    public Long getVersion() { return version; }
}
