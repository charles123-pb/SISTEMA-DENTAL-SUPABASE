package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface PatientAllergyRepository extends JpaRepository<PatientAllergy, Long> {
    List<PatientAllergy> findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(Long patientId);
    long countByPatientIdAndActivoTrueAndEstado(Long patientId, AllergyStatus status);
}
