package pe.com.dentalamericana.patient.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.UUID;

@Component
public class LocalPatientFileStorage implements PatientFileStorage {
    private final Path root;

    public LocalPatientFileStorage(@Value("${app.storage.patient-files-root}") String root) {
        this.root = Path.of(root).toAbsolutePath().normalize();
    }

    @Override
    public StoredPatientFile store(Long patientId, String originalName, InputStream content) throws IOException {
        Path patientDirectory = root.resolve(patientId.toString()).normalize();
        if (!patientDirectory.startsWith(root)) throw new IOException("Ruta de almacenamiento inválida");
        Files.createDirectories(patientDirectory);
        String internalName = UUID.randomUUID() + extension(originalName);
        Path target = patientDirectory.resolve(internalName).normalize();
        if (!target.startsWith(patientDirectory)) throw new IOException("Nombre de archivo inválido");
        Files.copy(content, target, StandardCopyOption.REPLACE_EXISTING);
        return new StoredPatientFile(internalName, root.relativize(target).toString());
    }

    @Override
    public Resource load(String location) {
        Path target = root.resolve(location).normalize();
        if (!target.startsWith(root)) throw new IllegalArgumentException("Ruta de archivo inválida");
        return new FileSystemResource(target);
    }

    @Override
    public void delete(String location) {
        try {
            Path target = root.resolve(location).normalize();
            if (target.startsWith(root)) Files.deleteIfExists(target);
        } catch (IOException ignored) {
            // La limpieza de un archivo huérfano no debe ocultar el error original de persistencia.
        }
    }

    private String extension(String name) {
        if (name == null) return "";
        String lower = name.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".pdf")) return ".pdf";
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return ".jpg";
        if (lower.endsWith(".png")) return ".png";
        return "";
    }
}
