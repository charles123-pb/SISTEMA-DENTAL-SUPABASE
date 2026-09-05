package pe.com.dentalamericana.patient.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record MedicationRequest(
        @NotBlank @Size(max = 180) String medication,
        @Size(max = 100) String dose,
        @Size(max = 100) String frequency,
        @Size(max = 250) String reason,
        LocalDate startDate,
        LocalDate endDate,
        boolean current
) {}
