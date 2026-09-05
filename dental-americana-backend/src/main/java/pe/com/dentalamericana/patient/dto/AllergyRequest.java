package pe.com.dentalamericana.patient.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import pe.com.dentalamericana.patient.AllergySeverity;
import pe.com.dentalamericana.patient.AllergyStatus;

public record AllergyRequest(
        @NotBlank @Size(max = 150) String substance,
        @Size(max = 300) String reaction,
        @NotNull AllergySeverity severity,
        @NotNull AllergyStatus status,
        @Size(max = 1000) String observation
) {}
