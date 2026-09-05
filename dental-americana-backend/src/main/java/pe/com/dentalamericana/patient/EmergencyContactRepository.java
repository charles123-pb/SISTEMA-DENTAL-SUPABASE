package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface EmergencyContactRepository extends JpaRepository<EmergencyContact, Long> {
    List<EmergencyContact> findAllByPatientIdAndActivoTrueOrderByPrincipalDescIdAsc(Long patientId);
}
