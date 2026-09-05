package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.*;
import java.time.Instant;
import java.time.LocalDate;

public record HistoryResponse(Long id, HistoryType type, String description, HistoryStatus status,
                              String observation, LocalDate reportedDate, Instant createdAt) {
    public static HistoryResponse from(PatientHistory value) {
        return new HistoryResponse(value.getId(), value.getType(), value.getDescription(), value.getStatus(),
                value.getObservation(), value.getReportedDate(), value.getCreatedAt());
    }
}
