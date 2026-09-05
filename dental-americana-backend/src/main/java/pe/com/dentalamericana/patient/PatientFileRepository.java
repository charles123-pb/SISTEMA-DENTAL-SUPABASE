package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface PatientFileRepository extends JpaRepository<PatientFile, Long> {
    List<PatientFile> findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(Long patientId);
    Optional<PatientFile> findByIdAndPatientIdAndActivoTrue(Long id, Long patientId);
}
