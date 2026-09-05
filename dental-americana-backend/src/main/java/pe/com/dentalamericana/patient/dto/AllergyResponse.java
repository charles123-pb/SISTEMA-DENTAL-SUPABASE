package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.*;
import java.time.Instant;

public record AllergyResponse(Long id, String substance, String reaction, AllergySeverity severity,
                              AllergyStatus status, String observation, Instant createdAt) {
    public static AllergyResponse from(PatientAllergy value) {
        return new AllergyResponse(value.getId(), value.getSubstance(), value.getReaction(), value.getSeverity(),
                value.getStatus(), value.getObservation(), value.getCreatedAt());
    }
}
