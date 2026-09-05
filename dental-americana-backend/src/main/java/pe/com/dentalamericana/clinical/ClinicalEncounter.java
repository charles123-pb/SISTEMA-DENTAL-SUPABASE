package pe.com.dentalamericana.clinical;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "atenciones_clinicas")
public class ClinicalEncounter {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "paciente_id", nullable = false) private Long patientId;
    @Column(name = "cita_id", unique = true) private Long appointmentId;
    @Column(name = "odontologo_id", nullable = false) private Long dentistId;
    @Column(name = "fecha_atencion", nullable = false) private Instant encounterDate;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private ClinicalStatus estado;
    @Column(name = "motivo_consulta", length = 1000) private String consultationReason;
    @Column(name = "tiempo_enfermedad", length = 250) private String illnessDuration;
    @Column(name = "signos_sintomas", length = 1500) private String signsSymptoms;
    @Column(name = "relato_cronologico", columnDefinition = "TEXT") private String chronologicalStory;
    @Column(name = "presion_sistolica") private Integer systolicPressure;
    @Column(name = "presion_diastolica") private Integer diastolicPressure;
    private Integer pulso;
    @Column(precision = 4, scale = 1) private BigDecimal temperatura;
    @Column(name = "frecuencia_respiratoria") private Integer respiratoryRate;
    @Column(name = "peso_kg", precision = 5, scale = 2) private BigDecimal weightKg;
    @Column(name = "talla_cm", precision = 5, scale = 2) private BigDecimal heightCm;
    @Column(name = "examen_general", columnDefinition = "TEXT") private String generalExam;
    @Column(name = "examen_odontologico", columnDefinition = "TEXT") private String dentalExam;
    @Column(columnDefinition = "TEXT") private String diagnostico;
    @Column(name = "plan_trabajo", columnDefinition = "TEXT") private String workPlan;
    @Column(length = 500) private String pronostico;
    @Column(columnDefinition = "TEXT") private String evolucion;
    @Column(columnDefinition = "TEXT") private String indicaciones;
    @Column(name = "fecha_proximo_control") private LocalDate nextControlDate;
    @Column(name = "alta_paciente", nullable = false) private boolean discharged;
    @Column(name = "observacion_alta", length = 1000) private String dischargeObservation;
    @Column(name = "consentimiento_paciente", nullable = false) private boolean patientConsent;
    @Column(name = "aprobado_por") private Long approvedBy;
    @Column(name = "aprobado_en") private Instant approvedAt;
    @Column(name = "creado_por", nullable = false, updatable = false) private Long createdBy;
    @Column(name = "actualizado_por", nullable = false) private Long updatedBy;
    @Column(name = "creado_en", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "actualizado_en", nullable = false) private Instant updatedAt;
    @Version @Column(nullable = false) private Long version;

    protected ClinicalEncounter() {}
    public ClinicalEncounter(Long patientId, Long appointmentId, Long dentistId, Long actorId) {
        this.patientId = patientId; this.appointmentId = appointmentId; this.dentistId = dentistId;
        this.encounterDate = Instant.now(); this.estado = ClinicalStatus.BORRADOR;
        this.createdBy = actorId; this.updatedBy = actorId;
    }
    public void update(String consultationReason, String illnessDuration, String signsSymptoms, String chronologicalStory,
                       Integer systolicPressure, Integer diastolicPressure, Integer pulse, BigDecimal temperature,
                       Integer respiratoryRate, BigDecimal weightKg, BigDecimal heightCm, String generalExam,
                       String dentalExam, String diagnosis, String workPlan, String prognosis, String evolution,
                       String instructions, LocalDate nextControlDate, boolean discharged,
                       String dischargeObservation, boolean patientConsent, Long actorId) {
        this.consultationReason = consultationReason; this.illnessDuration = illnessDuration;
        this.signsSymptoms = signsSymptoms; this.chronologicalStory = chronologicalStory;
        this.systolicPressure = systolicPressure; this.diastolicPressure = diastolicPressure; this.pulso = pulse;
        this.temperatura = temperature; this.respiratoryRate = respiratoryRate; this.weightKg = weightKg;
        this.heightCm = heightCm; this.generalExam = generalExam; this.dentalExam = dentalExam;
        this.diagnostico = diagnosis; this.workPlan = workPlan; this.pronostico = prognosis;
        this.evolucion = evolution; this.indicaciones = instructions; this.nextControlDate = nextControlDate;
        this.discharged = discharged; this.dischargeObservation = dischargeObservation;
        this.patientConsent = patientConsent; this.updatedBy = actorId;
    }
    public void finalizeBy(Long actorId) { estado = ClinicalStatus.FINALIZADA; approvedBy = actorId; approvedAt = Instant.now(); updatedBy = actorId; }
    public void annul(Long actorId) { estado = ClinicalStatus.ANULADA; updatedBy = actorId; }
    @PrePersist void onCreate() { Instant now = Instant.now(); createdAt = now; updatedAt = now; }
    @PreUpdate void onUpdate() { updatedAt = Instant.now(); }

    public Long getId() { return id; } public Long getPatientId() { return patientId; }
    public Long getAppointmentId() { return appointmentId; } public Long getDentistId() { return dentistId; }
    public Instant getEncounterDate() { return encounterDate; } public ClinicalStatus getStatus() { return estado; }
    public String getConsultationReason() { return consultationReason; } public String getIllnessDuration() { return illnessDuration; }
    public String getSignsSymptoms() { return signsSymptoms; } public String getChronologicalStory() { return chronologicalStory; }
    public Integer getSystolicPressure() { return systolicPressure; } public Integer getDiastolicPressure() { return diastolicPressure; }
    public Integer getPulse() { return pulso; } public BigDecimal getTemperature() { return temperatura; }
    public Integer getRespiratoryRate() { return respiratoryRate; } public BigDecimal getWeightKg() { return weightKg; }
    public BigDecimal getHeightCm() { return heightCm; } public String getGeneralExam() { return generalExam; }
    public String getDentalExam() { return dentalExam; } public String getDiagnosis() { return diagnostico; }
    public String getWorkPlan() { return workPlan; } public String getPrognosis() { return pronostico; }
    public String getEvolution() { return evolucion; } public String getInstructions() { return indicaciones; }
    public LocalDate getNextControlDate() { return nextControlDate; } public boolean isDischarged() { return discharged; }
    public String getDischargeObservation() { return dischargeObservation; } public boolean isPatientConsent() { return patientConsent; }
    public Long getApprovedBy() { return approvedBy; } public Instant getApprovedAt() { return approvedAt; }
    public Instant getCreatedAt() { return createdAt; } public Instant getUpdatedAt() { return updatedAt; }
    public Long getVersion() { return version; }
}
