package pe.com.dentalamericana.odontogram.dto;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
public record FindingStatusRequest(@NotNull Long version,@AssertTrue boolean professionalConfirmation){}
