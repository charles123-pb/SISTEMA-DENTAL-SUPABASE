package pe.com.dentalamericana.odontogram.dto;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
public record OdontogramObservationRequest(@Size(max=4000) String generalObservation,@NotNull Long version,@AssertTrue boolean professionalConfirmation){}
