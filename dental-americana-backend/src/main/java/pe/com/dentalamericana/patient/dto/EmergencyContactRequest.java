package pe.com.dentalamericana.patient.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EmergencyContactRequest(
        @NotBlank @Size(max = 150) String fullName,
        @NotBlank @Size(max = 60) String relationship,
        @NotBlank @Size(max = 20) String phone,
        boolean primary
) {}
