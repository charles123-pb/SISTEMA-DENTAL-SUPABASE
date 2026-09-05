package pe.com.dentalamericana.clinical.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;

public record FinalizeEncounterRequest(@NotNull Long version, @AssertTrue boolean confirmProfessionalApproval) {}
