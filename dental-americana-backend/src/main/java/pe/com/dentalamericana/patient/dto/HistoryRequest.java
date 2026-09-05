package pe.com.dentalamericana.patient.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import pe.com.dentalamericana.patient.HistoryStatus;
import pe.com.dentalamericana.patient.HistoryType;

import java.time.LocalDate;

public record HistoryRequest(
        @NotNull HistoryType type,
        @NotBlank @Size(max = 500) String description,
        @NotNull HistoryStatus status,
        @Size(max = 1000) String observation,
        LocalDate reportedDate
) {}
