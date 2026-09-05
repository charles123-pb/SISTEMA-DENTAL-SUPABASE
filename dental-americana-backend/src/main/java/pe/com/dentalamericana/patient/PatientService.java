package pe.com.dentalamericana.patient;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.common.BusinessConflictException;
import pe.com.dentalamericana.common.ResourceNotFoundException;
import pe.com.dentalamericana.patient.dto.*;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.user.AppUser;
import pe.com.dentalamericana.user.AppUserRepository;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class PatientService {
    private static final Set<String> ALLOWED_SORTS = Set.of("fullName", "createdAt", "historyNumber", "birthDate");

    private final PatientRepository patients;
    private final EmergencyContactRepository emergencyContacts;
    private final PatientHistoryRepository histories;
    private final PatientAllergyRepository allergies;
    private final PatientMedicationRepository medications;
    private final PatientFileRepository files;
    private final AppUserRepository users;
    private final PatientMapper mapper;
    private final AuditService audit;

    public PatientService(PatientRepository patients, EmergencyContactRepository emergencyContacts,
                          PatientHistoryRepository histories, PatientAllergyRepository allergies,
                          PatientMedicationRepository medications, PatientFileRepository files,
                          AppUserRepository users, PatientMapper mapper, AuditService audit) {
        this.patients = patients; this.emergencyContacts = emergencyContacts; this.histories = histories;
        this.allergies = allergies; this.medications = medications; this.files = files; this.users = users;
        this.mapper = mapper; this.audit = audit;
    }

    @Transactional(readOnly = true)
    public PageResponse<PatientSummaryResponse> search(String query, Boolean active, Sex sex,
                                                       Integer minAge, Integer maxAge,
                                                       LocalDate registeredFrom, LocalDate registeredTo,
                                                       int page, int size, String sort, String direction) {
        int safeSize = Math.min(Math.max(size, 1), 100);
        String safeSort = ALLOWED_SORTS.contains(sort) ? sort : "fullName";
        Sort.Direction safeDirection = "desc".equalsIgnoreCase(direction) ? Sort.Direction.DESC : Sort.Direction.ASC;
        Sort jpaSort = switch (safeSort) {
            case "fullName" -> Sort.by(safeDirection, "paternalSurname", "maternalSurname", "firstNames");
            default -> Sort.by(safeDirection, safeSort);
        };
        var result = patients.findAll(PatientSpecification.filter(query, active, sex, minAge, maxAge,
                registeredFrom, registeredTo), PageRequest.of(Math.max(page, 0), safeSize, jpaSort));
        return PageResponse.from(result.map(patient -> PatientSummaryResponse.from(patient,
                allergies.countByPatientIdAndActivoTrueAndEstado(patient.getId(), AllergyStatus.ACTIVA))));
    }

    @Transactional(readOnly = true)
    public PatientDetailResponse get(Long id) { return detail(find(id)); }

    @Transactional(readOnly = true)
    public List<DuplicateCandidateResponse> duplicates(String documentNumber, String mobile,
                                                       LocalDate birthDate, String paternalSurname) {
        String doc = normalize(documentNumber);
        String normalizedMobile = digitsOrNull(mobile);
        String surname = normalizeName(paternalSurname);
        if (doc == null && normalizedMobile == null && (birthDate == null || surname == null)) return List.of();
        return patients.findDuplicateCandidates(doc, normalizedMobile, birthDate, surname).stream().limit(10).map(patient -> {
            String reason = doc != null && doc.equalsIgnoreCase(patient.getDocumentNumber()) ? "Mismo documento"
                    : normalizedMobile != null && normalizedMobile.equals(patient.getMobile()) ? "Mismo teléfono"
                    : "Misma fecha de nacimiento y apellido";
            return new DuplicateCandidateResponse(patient.getId(), patient.getHistoryNumber(), fullName(patient),
                    patient.getDocumentNumber(), patient.getMobile(), reason);
        }).toList();
    }

    @Transactional
    public PatientDetailResponse create(CreatePatientRequest request, AuthenticatedUser actor,
                                        HttpServletRequest httpRequest) {
        validateRequest(request.documentType(), request.documentNumber(), request.birthDate(),
                request.responsibleName(), request.responsibleRelationship(), request.responsiblePhone(), null);
        validateWhatsAppConsent(request.mobile(), request.whatsappConsent());
        String documentNumber = normalizeDocument(request.documentType(), request.documentNumber());
        if (documentNumber != null && patients.existsByDocumentNumberIgnoreCase(documentNumber)) {
            throw new BusinessConflictException("Ya existe un paciente con ese documento");
        }
        String historyNumber = "HC-%06d".formatted(patients.nextHistorySequence());
        Patient patient = new Patient(historyNumber, actor.getId());
        apply(patient, request.documentType(), documentNumber, request.firstNames(), request.paternalSurname(),
                request.maternalSurname(), request.birthDate(), request.sex(), request.birthPlace(), request.occupation(),
                request.maritalStatus(), request.educationLevel(), request.religion(), request.ethnicSelfIdentification(),
                request.mobile(), request.whatsappConsent(), request.phone(), request.email(), request.address(), request.responsibleName(),
                request.responsibleDocument(), request.responsibleRelationship(), request.responsiblePhone(), actor.getId());
        try {
            patients.saveAndFlush(patient);
        } catch (DataIntegrityViolationException exception) {
            throw new BusinessConflictException("No se pudo crear: el documento o número de historia ya existe");
        }
        if (request.emergencyContact() != null) {
            emergencyContacts.save(toEmergency(patient.getId(), request.emergencyContact(), actor.getId()));
        }
        audit.record(actorEntity(actor), "CREAR_PACIENTE", "PACIENTE", patient.getId().toString(), AuditResult.EXITO,
                "Historia " + patient.getHistoryNumber(), httpRequest);
        return detail(patient);
    }

    @Transactional
    public PatientDetailResponse update(Long id, UpdatePatientRequest request, AuthenticatedUser actor,
                                        HttpServletRequest httpRequest) {
        Patient patient = find(id);
        if (!patient.getVersion().equals(request.version())) throw new BusinessConflictException("El paciente fue modificado por otro usuario");
        validateRequest(request.documentType(), request.documentNumber(), request.birthDate(),
                request.responsibleName(), request.responsibleRelationship(), request.responsiblePhone(), id);
        validateWhatsAppConsent(request.mobile(), request.whatsappConsent());
        String documentNumber = normalizeDocument(request.documentType(), request.documentNumber());
        if (documentNumber != null && patients.existsByDocumentNumberIgnoreCaseAndIdNot(documentNumber, id)) {
            throw new BusinessConflictException("Ya existe otro paciente con ese documento");
        }
        apply(patient, request.documentType(), documentNumber, request.firstNames(), request.paternalSurname(),
                request.maternalSurname(), request.birthDate(), request.sex(), request.birthPlace(), request.occupation(),
                request.maritalStatus(), request.educationLevel(), request.religion(), request.ethnicSelfIdentification(),
                request.mobile(), request.whatsappConsent(), request.phone(), request.email(), request.address(), request.responsibleName(),
                request.responsibleDocument(), request.responsibleRelationship(), request.responsiblePhone(), actor.getId());
        audit.record(actorEntity(actor), "ACTUALIZAR_PACIENTE", "PACIENTE", id.toString(), AuditResult.EXITO,
                "Datos administrativos actualizados", httpRequest);
        return detail(patient);
    }

    @Transactional
    public PatientDetailResponse changeStatus(Long id, PatientStatusRequest request, AuthenticatedUser actor,
                                              HttpServletRequest httpRequest) {
        Patient patient = find(id);
        if (!patient.getVersion().equals(request.version())) throw new BusinessConflictException("El paciente fue modificado por otro usuario");
        patient.changeActive(request.active(), actor.getId());
        audit.record(actorEntity(actor), request.active() ? "REACTIVAR_PACIENTE" : "DESACTIVAR_PACIENTE",
                "PACIENTE", id.toString(), AuditResult.EXITO, null, httpRequest);
        return detail(patient);
    }

    public Patient find(Long id) {
        return patients.findById(id).orElseThrow(() -> new ResourceNotFoundException("Paciente no encontrado"));
    }

    public AppUser actorEntity(AuthenticatedUser actor) { return users.findById(actor.getId()).orElse(null); }

    private PatientDetailResponse detail(Patient patient) {
        return mapper.toDetail(patient,
                emergencyContacts.findAllByPatientIdAndActivoTrueOrderByPrincipalDescIdAsc(patient.getId()),
                histories.findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(patient.getId()),
                allergies.findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(patient.getId()),
                medications.findAllByPatientIdAndActivoTrueOrderByVigenteDescCreatedAtDesc(patient.getId()),
                files.findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(patient.getId()));
    }

    private void apply(Patient patient, DocumentType documentType, String documentNumber, String firstNames,
                       String paternalSurname, String maternalSurname, LocalDate birthDate, Sex sex,
                       String birthPlace, String occupation, String maritalStatus, String educationLevel,
                       String religion, String ethnicSelfIdentification, String mobile, boolean whatsappConsent,
                       String phone, String email,
                       String address, String responsibleName, String responsibleDocument,
                       String responsibleRelationship, String responsiblePhone, Long actorId) {
        patient.updateIdentity(documentType, documentNumber, requiredName(firstNames), requiredName(paternalSurname),
                normalizeName(maternalSurname), birthDate, sex);
        patient.updateAdditional(normalizeText(birthPlace), normalizeText(occupation), normalizeText(maritalStatus),
                normalizeText(educationLevel), normalizeText(religion), normalizeText(ethnicSelfIdentification));
        patient.updateContact(digitsOrNull(mobile), digitsOrNull(phone), normalizeEmail(email), normalizeText(address));
        patient.updateWhatsAppConsent(whatsappConsent, actorId);
        patient.updateResponsible(normalizeName(responsibleName), normalize(responsibleDocument),
                normalizeText(responsibleRelationship), digitsOrNull(responsiblePhone));
        patient.markUpdatedBy(actorId);
    }

    private void validateRequest(DocumentType type, String document, LocalDate birthDate,
                                 String responsibleName, String relationship, String responsiblePhone, Long id) {
        String normalized = normalize(document);
        if (type == DocumentType.SIN_DOCUMENTO && normalized != null) throw new BusinessConflictException("SIN_DOCUMENTO no debe incluir número");
        if (type != DocumentType.SIN_DOCUMENTO && normalized == null) throw new BusinessConflictException("El número de documento es obligatorio");
        if (type == DocumentType.DNI && (normalized == null || !normalized.matches("\\d{8}"))) {
            throw new BusinessConflictException("El DNI debe tener ocho dígitos");
        }
        if (birthDate.isAfter(LocalDate.now())) throw new BusinessConflictException("La fecha de nacimiento no puede ser futura");
        if (Period.between(birthDate, LocalDate.now()).getYears() < 18
                && (normalizeName(responsibleName) == null || normalizeText(relationship) == null || digitsOrNull(responsiblePhone) == null)) {
            throw new BusinessConflictException("Los menores de edad requieren responsable, parentesco y teléfono");
        }
    }

    private void validateWhatsAppConsent(String mobile, boolean consent) {
        if (consent && digitsOrNull(mobile) == null) {
            throw new BusinessConflictException("Registre un celular antes de autorizar WhatsApp");
        }
    }

    private EmergencyContact toEmergency(Long patientId, EmergencyContactRequest request, Long actorId) {
        return new EmergencyContact(patientId, requiredName(request.fullName()), requiredName(request.relationship()),
                requiredName(request.phone()), request.primary(), actorId);
    }

    private String fullName(Patient patient) {
        return String.join(" ", patient.getFirstNames(), patient.getPaternalSurname(),
                patient.getMaternalSurname() == null ? "" : patient.getMaternalSurname()).trim();
    }
    private String requiredName(String value) { return value.trim().replaceAll("\\s+", " "); }
    private String normalizeName(String value) { String normalized = normalizeText(value); return normalized == null ? null : normalized.replaceAll("\\s+", " "); }
    private String normalizeText(String value) { return value == null || value.isBlank() ? null : value.trim(); }
    private String normalize(String value) { return value == null || value.isBlank() ? null : value.trim().toUpperCase(Locale.ROOT); }
    private String normalizeEmail(String value) { return value == null || value.isBlank() ? null : value.trim().toLowerCase(Locale.ROOT); }
    private String digitsOrNull(String value) { if (value == null || value.isBlank()) return null; String digits = value.replaceAll("\\D", ""); return digits.isBlank() ? null : digits; }
    private String normalizeDocument(DocumentType type, String value) { return type == DocumentType.SIN_DOCUMENTO ? null : normalize(value); }
}
