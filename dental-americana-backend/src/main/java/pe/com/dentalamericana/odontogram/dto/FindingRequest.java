package pe.com.dentalamericana.odontogram.dto;
import jakarta.validation.constraints.*;
import pe.com.dentalamericana.odontogram.*;
public record FindingRequest(@NotBlank @Pattern(regexp="^[1-8][1-8]$") String tooth,@NotNull ToothSurface surface,
 @NotNull ToothCondition condition,@NotNull TreatmentState treatmentState,@Size(max=500) String observation,
 @AssertTrue boolean professionalConfirmation){}
