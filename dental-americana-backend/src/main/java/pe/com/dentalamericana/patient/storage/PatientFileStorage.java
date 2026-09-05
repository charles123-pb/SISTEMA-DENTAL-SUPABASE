package pe.com.dentalamericana.patient.storage;

import org.springframework.core.io.Resource;

import java.io.IOException;
import java.io.InputStream;

public interface PatientFileStorage {
    StoredPatientFile store(Long patientId, String originalName, InputStream content) throws IOException;
    Resource load(String location);
    void delete(String location);
}
