package pe.com.dentalamericana.appointment.dto;

import pe.com.dentalamericana.appointment.AppointmentType;

public record AppointmentTypeResponse(Long id, String code, String name, int durationMinutes, String color) {
    public static AppointmentTypeResponse from(AppointmentType type) {
        return new AppointmentTypeResponse(type.getId(), type.getCode(), type.getName(), type.getDurationMinutes(), type.getColor());
    }
}
