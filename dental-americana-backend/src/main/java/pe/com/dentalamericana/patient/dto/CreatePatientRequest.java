package pe.com.dentalamericana.patient.dto;

import jakarta.validation.constraints.*;
import pe.com.dentalamericana.patient.DocumentType;
import pe.com.dentalamericana.patient.Sex;

import java.time.LocalDate;

public record CreatePatientRequest(
        @NotNull DocumentType documentType,
        @Size(max = 20) String documentNumber,
        @NotBlank @Size(max = 100) String firstNames,
        @NotBlank @Size(max = 80) String paternalSurname,
        @Size(max = 80) String maternalSurname,
        @NotNull @PastOrPresent LocalDate birthDate,
        @NotNull Sex sex,
        @Size(max = 150) String birthPlace,
        @Size(max = 120) String occupation,
        @Size(max = 30) String maritalStatus,
        @Size(max = 60) String educationLevel,
        @Size(max = 80) String religion,
        @Size(max = 100) String ethnicSelfIdentification,
        @Pattern(regexp = "^$|^[0-9+ ()-]{6,20}$", message = "Celular inválido") String mobile,
        boolean whatsappConsent,
        @Pattern(regexp = "^$|^[0-9+ ()-]{6,20}$", message = "Teléfono inválido") String phone,
        @Email @Size(max = 150) String email,
        @Size(max = 250) String address,
        @Size(max = 150) String responsibleName,
        @Size(max = 20) String responsibleDocument,
        @Size(max = 60) String responsibleRelationship,
        @Size(max = 20) String responsiblePhone,
        EmergencyContactRequest emergencyContact
) {}
