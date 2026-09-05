package pe.com.dentalamericana.patient;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.common.ResourceNotFoundException;
import pe.com.dentalamericana.common.UnsupportedFileException;
import pe.com.dentalamericana.patient.dto.FileResponse;
import pe.com.dentalamericana.patient.storage.PatientFileStorage;
import pe.com.dentalamericana.patient.storage.StoredPatientFile;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.io.IOException;
import java.util.Locale;
import java.util.Set;

@Service
public class PatientFileService {
    private static final Set<String> TYPES = Set.of("application/pdf", "image/jpeg", "image/png");
    private final PatientService patients;
    private final PatientFileRepository files;
    private final PatientFileStorage storage;
    private final AuditService audit;
    private final long maxBytes;

    public PatientFileService(PatientService patients, PatientFileRepository files, PatientFileStorage storage,
                              AuditService audit, @Value("${app.storage.patient-files-max-bytes}") long maxBytes) {
        this.patients = patients; this.files = files; this.storage = storage; this.audit = audit; this.maxBytes = maxBytes;
    }

    @Transactional
    public FileResponse upload(Long patientId, PatientFileCategory category, String description, MultipartFile upload,
                               AuthenticatedUser actor, HttpServletRequest httpRequest) {
        Patient patient = patients.find(patientId);
        if (!patient.isActive()) throw new UnsupportedFileException(HttpStatus.CONFLICT, "El paciente está inactivo");
        validate(upload);
        String originalName = sanitize(upload.getOriginalFilename());
        StoredPatientFile stored;
        try {
            stored = storage.store(patientId, originalName, upload.getInputStream());
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo almacenar el archivo");
        }
        try {
            PatientFile saved = files.saveAndFlush(new PatientFile(patientId, category, originalName,
                    stored.internalName(), upload.getContentType(), upload.getSize(), stored.location(),
                    trim(description), actor.getId()));
            audit.record(patients.actorEntity(actor), "SUBIR_ARCHIVO_PACIENTE", "PACIENTE", patientId.toString(),
                    AuditResult.EXITO, "Archivo " + saved.getId() + ", categoría " + category, httpRequest);
            return FileResponse.from(saved);
        } catch (RuntimeException exception) {
            storage.delete(stored.location());
            throw exception;
        }
    }

    @Transactional(readOnly = true)
    public PatientFileDownload download(Long patientId, Long fileId, AuthenticatedUser actor,
                                        HttpServletRequest httpRequest) {
        patients.find(patientId);
        PatientFile metadata = files.findByIdAndPatientIdAndActivoTrue(fileId, patientId)
                .orElseThrow(() -> new ResourceNotFoundException("Archivo no encontrado"));
        Resource resource = storage.load(metadata.getLocation());
        if (!resource.exists() || !resource.isReadable()) throw new ResourceNotFoundException("El archivo físico no está disponible");
        audit.record(patients.actorEntity(actor), "DESCARGAR_ARCHIVO_PACIENTE", "PACIENTE", patientId.toString(),
                AuditResult.EXITO, "Archivo " + fileId, httpRequest);
        return new PatientFileDownload(metadata, resource);
    }

    private void validate(MultipartFile upload) {
        if (upload == null || upload.isEmpty()) throw new UnsupportedFileException(HttpStatus.BAD_REQUEST, "Seleccione un archivo");
        if (upload.getSize() > maxBytes) throw new UnsupportedFileException(HttpStatus.PAYLOAD_TOO_LARGE, "El archivo supera 10 MB");
        if (upload.getContentType() == null || !TYPES.contains(upload.getContentType().toLowerCase(Locale.ROOT))) {
            throw new UnsupportedFileException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "Solo se permiten PDF, JPG y PNG");
        }
        String name = sanitize(upload.getOriginalFilename()).toLowerCase(Locale.ROOT);
        boolean extensionAllowed = name.endsWith(".pdf") || name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png");
        if (!extensionAllowed) throw new UnsupportedFileException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "La extensión del archivo no está permitida");
    }

    private String sanitize(String value) {
        String base = value == null ? "archivo" : value.replace('\\', '/');
        base = base.substring(base.lastIndexOf('/') + 1).replaceAll("[\\r\\n]", "_").trim();
        return base.isBlank() ? "archivo" : base.substring(0, Math.min(base.length(), 255));
    }
    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }
}
