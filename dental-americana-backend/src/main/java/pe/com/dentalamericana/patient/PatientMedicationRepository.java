package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface PatientMedicationRepository extends JpaRepository<PatientMedication, Long> {
    List<PatientMedication> findAllByPatientIdAndActivoTrueOrderByVigenteDescCreatedAtDesc(Long patientId);
}
