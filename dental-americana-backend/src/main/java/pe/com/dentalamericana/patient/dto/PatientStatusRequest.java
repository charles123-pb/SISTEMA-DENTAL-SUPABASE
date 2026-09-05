package pe.com.dentalamericana.patient.dto;

import jakarta.validation.constraints.NotNull;

public record PatientStatusRequest(@NotNull Boolean active, @NotNull Long version) {}
