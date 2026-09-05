package pe.com.dentalamericana.patient;

import org.springframework.core.io.Resource;

public record PatientFileDownload(PatientFile metadata, Resource resource) {}
