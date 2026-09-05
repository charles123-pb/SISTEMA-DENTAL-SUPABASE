package pe.com.dentalamericana.appointment.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import pe.com.dentalamericana.appointment.AppointmentStatus;

public record AppointmentStatusRequest(
        @NotNull AppointmentStatus status,
        @Size(max = 500) String reason,
        @NotNull Long version
) {}
