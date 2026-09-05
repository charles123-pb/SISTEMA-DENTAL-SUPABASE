package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public record PatientDetailResponse(
        Long id, String historyNumber, DocumentType documentType, String documentNumber,
        String firstNames, String paternalSurname, String maternalSurname, LocalDate birthDate,
        int age, Sex sex, String birthPlace, String occupation, String maritalStatus,
        String educationLevel, String religion, String ethnicSelfIdentification,
        String mobile, String phone, boolean whatsappConsent, Instant whatsappConsentAt,
        Long whatsappConsentBy, Instant whatsappRevokedAt, String email, String address,
        String responsibleName, String responsibleDocument, String responsibleRelationship, String responsiblePhone,
        boolean active, Instant createdAt, Instant updatedAt, Long version,
        List<EmergencyContactResponse> emergencyContacts, List<HistoryResponse> histories,
        List<AllergyResponse> allergies, List<MedicationResponse> medications, List<FileResponse> files
) {}
