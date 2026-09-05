package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.DocumentType;
import pe.com.dentalamericana.patient.Patient;
import pe.com.dentalamericana.patient.Sex;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;

public record PatientSummaryResponse(
        Long id, String historyNumber, DocumentType documentType, String documentNumber,
        String fullName, LocalDate birthDate, int age, Sex sex, String mobile, boolean whatsappConsent,
        String email, long activeAllergies, boolean active, Instant createdAt, Long version
) {
    public static PatientSummaryResponse from(Patient patient, long activeAllergies) {
        String name = String.join(" ", patient.getFirstNames(), patient.getPaternalSurname(),
                patient.getMaternalSurname() == null ? "" : patient.getMaternalSurname()).trim();
        return new PatientSummaryResponse(patient.getId(), patient.getHistoryNumber(), patient.getDocumentType(),
                patient.getDocumentNumber(), name, patient.getBirthDate(), Period.between(patient.getBirthDate(), LocalDate.now()).getYears(),
                patient.getSex(), patient.getMobile(), patient.isWhatsAppConsent(), patient.getEmail(), activeAllergies, patient.isActive(),
                patient.getCreatedAt(), patient.getVersion());
    }
}
