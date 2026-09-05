package pe.com.dentalamericana.clinical;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface ClinicalEncounterRepository extends JpaRepository<ClinicalEncounter, Long> {
    Optional<ClinicalEncounter> findByAppointmentId(Long appointmentId);
    List<ClinicalEncounter> findAllByPatientIdOrderByEncounterDateDesc(Long patientId);
    @Query("select e from ClinicalEncounter e where e.encounterDate >= :from and e.encounterDate < :to and (:status is null or e.estado = :status) order by e.encounterDate desc")
    List<ClinicalEncounter> search(@Param("from") Instant from, @Param("to") Instant to, @Param("status") ClinicalStatus status);
    long countByEncounterDateBetweenAndEstado(Instant from,Instant to,ClinicalStatus status);
}
