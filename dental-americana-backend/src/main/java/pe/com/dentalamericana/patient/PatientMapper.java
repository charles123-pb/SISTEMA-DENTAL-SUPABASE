package pe.com.dentalamericana.patient;

import org.springframework.stereotype.Component;
import pe.com.dentalamericana.patient.dto.*;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;

@Component
public class PatientMapper {
    public PatientDetailResponse toDetail(Patient patient,
                                          List<EmergencyContact> contacts,
                                          List<PatientHistory> histories,
                                          List<PatientAllergy> allergies,
                                          List<PatientMedication> medications,
                                          List<PatientFile> files) {
        return new PatientDetailResponse(
                patient.getId(), patient.getHistoryNumber(), patient.getDocumentType(), patient.getDocumentNumber(),
                patient.getFirstNames(), patient.getPaternalSurname(), patient.getMaternalSurname(),
                patient.getBirthDate(), Period.between(patient.getBirthDate(), LocalDate.now()).getYears(), patient.getSex(),
                patient.getBirthPlace(), patient.getOccupation(), patient.getMaritalStatus(), patient.getEducationLevel(),
                patient.getReligion(), patient.getEthnicSelfIdentification(), patient.getMobile(), patient.getPhone(),
                patient.isWhatsAppConsent(), patient.getWhatsAppConsentAt(), patient.getWhatsAppConsentBy(),
                patient.getWhatsAppRevokedAt(), patient.getEmail(), patient.getAddress(),
                patient.getResponsibleName(), patient.getResponsibleDocument(),
                patient.getResponsibleRelationship(), patient.getResponsiblePhone(), patient.isActive(), patient.getCreatedAt(),
                patient.getUpdatedAt(), patient.getVersion(),
                contacts.stream().map(EmergencyContactResponse::from).toList(),
                histories.stream().map(HistoryResponse::from).toList(),
                allergies.stream().map(AllergyResponse::from).toList(),
                medications.stream().map(MedicationResponse::from).toList(),
                files.stream().map(FileResponse::from).toList()
        );
    }
}
