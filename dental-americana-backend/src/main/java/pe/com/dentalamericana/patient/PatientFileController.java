package pe.com.dentalamericana.patient;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pe.com.dentalamericana.patient.dto.FileResponse;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.nio.charset.StandardCharsets;

@RestController
@RequestMapping("/api/v1/patients/{patientId}/files")
public class PatientFileController {
    private final PatientFileService service;

    public PatientFileController(PatientFileService service) { this.service = service; }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyAuthority('PACIENTE_ESCRIBIR','CLINICA_ESCRIBIR')")
    public FileResponse upload(@PathVariable Long patientId,
                               @RequestParam PatientFileCategory category,
                               @RequestParam(required = false) String description,
                               @RequestPart("file") MultipartFile file,
                               @AuthenticationPrincipal AuthenticatedUser actor,
                               HttpServletRequest httpRequest) {
        return service.upload(patientId, category, description, file, actor, httpRequest);
    }

    @GetMapping("/{fileId}")
    @PreAuthorize("hasAnyAuthority('PACIENTE_LEER','CLINICA_LEER')")
    public ResponseEntity<org.springframework.core.io.Resource> download(@PathVariable Long patientId,
                                                                         @PathVariable Long fileId,
                                                                         @AuthenticationPrincipal AuthenticatedUser actor,
                                                                         HttpServletRequest httpRequest) {
        PatientFileDownload download = service.download(patientId, fileId, actor, httpRequest);
        MediaType mediaType = MediaType.parseMediaType(download.metadata().getContentType());
        ContentDisposition disposition = ContentDisposition.attachment()
                .filename(download.metadata().getOriginalName(), StandardCharsets.UTF_8).build();
        return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .contentLength(download.metadata().getSizeBytes())
                .body(download.resource());
    }
}
