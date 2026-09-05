package pe.com.dentalamericana.odontogram.dto;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import pe.com.dentalamericana.odontogram.DentitionType;
public record OdontogramRequest(@NotNull DentitionType dentitionType,@Size(max=4000) String generalObservation,@AssertTrue boolean professionalConfirmation){}
