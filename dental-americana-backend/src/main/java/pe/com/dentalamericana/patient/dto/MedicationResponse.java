package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.PatientMedication;
import java.time.Instant;
import java.time.LocalDate;

public record MedicationResponse(Long id, String medication, String dose, String frequency, String reason,
                                 LocalDate startDate, LocalDate endDate, boolean current, Instant createdAt) {
    public static MedicationResponse from(PatientMedication value) {
        return new MedicationResponse(value.getId(), value.getMedication(), value.getDose(), value.getFrequency(),
                value.getReason(), value.getStartDate(), value.getEndDate(), value.isCurrent(), value.getCreatedAt());
    }
}
