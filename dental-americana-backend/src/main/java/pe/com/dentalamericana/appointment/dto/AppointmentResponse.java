package pe.com.dentalamericana.appointment.dto;

import pe.com.dentalamericana.appointment.AppointmentSource;
import pe.com.dentalamericana.appointment.AppointmentStatus;
import java.time.Instant;

public record AppointmentResponse(
        Long id, Long patientId, String patientHistoryNumber, String patientName, String patientMobile,
        Long professionalId, String professionalName, Long appointmentTypeId, String appointmentTypeName,
        String appointmentTypeColor, int durationMinutes, Instant start, Instant end, AppointmentStatus status,
        String reason, String notes, AppointmentSource source, String cancellationReason,
        boolean confirmationSent, boolean reminderScheduled, boolean reminderSent,
        Instant createdAt, Instant updatedAt, Long version
) {}
