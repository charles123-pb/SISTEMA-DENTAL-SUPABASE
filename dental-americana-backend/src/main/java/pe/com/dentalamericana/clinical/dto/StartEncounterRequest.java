package pe.com.dentalamericana.clinical.dto;

import jakarta.validation.constraints.NotNull;

public record StartEncounterRequest(@NotNull Long patientId, Long appointmentId) {}
