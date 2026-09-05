package pe.com.dentalamericana.patient.dto;

import pe.com.dentalamericana.patient.PatientFile;
import pe.com.dentalamericana.patient.PatientFileCategory;
import java.time.Instant;

public record FileResponse(Long id, PatientFileCategory category, String originalName, String contentType,
                           long sizeBytes, String description, Instant createdAt) {
    public static FileResponse from(PatientFile value) {
        return new FileResponse(value.getId(), value.getCategory(), value.getOriginalName(), value.getContentType(),
                value.getSizeBytes(), value.getDescription(), value.getCreatedAt());
    }
}
