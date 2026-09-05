package pe.com.dentalamericana.patient;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.common.BusinessConflictException;
import pe.com.dentalamericana.patient.dto.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

@Service
public class PatientClinicalDataService {
    private final PatientService patients;
    private final EmergencyContactRepository contacts;
    private final PatientHistoryRepository histories;
    private final PatientAllergyRepository allergies;
    private final PatientMedicationRepository medications;
    private final AuditService audit;

    public PatientClinicalDataService(PatientService patients, EmergencyContactRepository contacts,
                                      PatientHistoryRepository histories, PatientAllergyRepository allergies,
                                      PatientMedicationRepository medications, AuditService audit) {
        this.patients = patients; this.contacts = contacts; this.histories = histories;
        this.allergies = allergies; this.medications = medications; this.audit = audit;
    }

    @Transactional
    public EmergencyContactResponse addContact(Long patientId, EmergencyContactRequest request,
                                               AuthenticatedUser actor, HttpServletRequest httpRequest) {
        ensureActive(patientId);
        EmergencyContact saved = contacts.save(new EmergencyContact(patientId, request.fullName().trim(),
                request.relationship().trim(), request.phone().replaceAll("\\D", ""), request.primary(), actor.getId()));
        record(actor, "AGREGAR_CONTACTO_EMERGENCIA", patientId, saved.getId(), httpRequest);
        return EmergencyContactResponse.from(saved);
    }

    @Transactional
    public HistoryResponse addHistory(Long patientId, HistoryRequest request,
                                      AuthenticatedUser actor, HttpServletRequest httpRequest) {
        ensureActive(patientId);
        PatientHistory saved = histories.save(new PatientHistory(patientId, request.type(), request.description().trim(),
                request.status(), trim(request.observation()), request.reportedDate(), actor.getId()));
        record(actor, "AGREGAR_ANTECEDENTE", patientId, saved.getId(), httpRequest);
        return HistoryResponse.from(saved);
    }

    @Transactional
    public AllergyResponse addAllergy(Long patientId, AllergyRequest request,
                                      AuthenticatedUser actor, HttpServletRequest httpRequest) {
        ensureActive(patientId);
        PatientAllergy saved = allergies.save(new PatientAllergy(patientId, request.substance().trim(),
                trim(request.reaction()), request.severity(), request.status(), trim(request.observation()), actor.getId()));
        record(actor, "AGREGAR_ALERGIA", patientId, saved.getId(), httpRequest);
        return AllergyResponse.from(saved);
    }

    @Transactional
    public MedicationResponse addMedication(Long patientId, MedicationRequest request,
                                            AuthenticatedUser actor, HttpServletRequest httpRequest) {
        ensureActive(patientId);
        if (request.startDate() != null && request.endDate() != null && request.endDate().isBefore(request.startDate())) {
            throw new BusinessConflictException("La fecha final del medicamento no puede ser anterior al inicio");
        }
        PatientMedication saved = medications.save(new PatientMedication(patientId, request.medication().trim(),
                trim(request.dose()), trim(request.frequency()), trim(request.reason()), request.startDate(),
                request.endDate(), request.current(), actor.getId()));
        record(actor, "AGREGAR_MEDICAMENTO", patientId, saved.getId(), httpRequest);
        return MedicationResponse.from(saved);
    }

    private void ensureActive(Long patientId) {
        if (!patients.find(patientId).isActive()) throw new BusinessConflictException("El paciente está inactivo");
    }

    private void record(AuthenticatedUser actor, String action, Long patientId, Long itemId, HttpServletRequest request) {
        audit.record(patients.actorEntity(actor), action, "PACIENTE", patientId.toString(), AuditResult.EXITO,
                "Subregistro " + itemId, request);
    }

    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
