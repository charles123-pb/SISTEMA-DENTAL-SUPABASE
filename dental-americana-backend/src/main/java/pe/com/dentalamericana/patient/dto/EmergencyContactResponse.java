package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.EmergencyContact;
import java.time.Instant;

public record EmergencyContactResponse(Long id, String fullName, String relationship, String phone,
                                       boolean primary, Instant createdAt) {
    public static EmergencyContactResponse from(EmergencyContact value) {
        return new EmergencyContactResponse(value.getId(), value.getFullName(), value.getRelationship(),
                value.getPhone(), value.isPrimary(), value.getCreatedAt());
    }
}
