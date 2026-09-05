package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface PatientHistoryRepository extends JpaRepository<PatientHistory, Long> {
    List<PatientHistory> findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(Long patientId);
}
