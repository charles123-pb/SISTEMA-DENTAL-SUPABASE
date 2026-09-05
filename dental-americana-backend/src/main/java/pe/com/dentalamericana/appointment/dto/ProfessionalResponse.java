package pe.com.dentalamericana.appointment.dto;

import pe.com.dentalamericana.user.AppUser;

public record ProfessionalResponse(Long id, String fullName) {
    public static ProfessionalResponse from(AppUser user) { return new ProfessionalResponse(user.getId(), user.getFullName()); }
}
