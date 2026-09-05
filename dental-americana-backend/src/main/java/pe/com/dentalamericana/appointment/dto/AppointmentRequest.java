package pe.com.dentalamericana.appointment.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import pe.com.dentalamericana.appointment.AppointmentSource;

import java.time.Instant;

public record AppointmentRequest(
        @NotNull Long patientId,
        @NotNull Long professionalId,
        @NotNull Long appointmentTypeId,
        @NotNull @Future Instant start,
        @NotBlank @Size(max = 500) String reason,
        @Size(max = 1000) String notes,
        AppointmentSource source,
        Long version
) {}
