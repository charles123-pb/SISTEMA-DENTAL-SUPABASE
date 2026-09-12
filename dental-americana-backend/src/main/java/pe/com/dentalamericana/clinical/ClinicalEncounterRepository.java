package pe.com.dentalamericana.clinical;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface ClinicalEncounterRepository extends JpaRepository<ClinicalEncounter, Long>, org.springframework.data.jpa.repository.JpaSpecificationExecutor<ClinicalEncounter> {
    Optional<ClinicalEncounter> findByAppointmentId(Long appointmentId);
    List<ClinicalEncounter> findAllByPatientIdOrderByEncounterDateDesc(Long patientId);
    default List<ClinicalEncounter> search(Instant from, Instant to, ClinicalStatus status) {
        return findAll((root, query, cb) -> {
            var range = cb.and(cb.greaterThanOrEqualTo(root.get("encounterDate"), from), cb.lessThan(root.get("encounterDate"), to));
            return status == null ? range : cb.and(range, cb.equal(root.get("estado"), status));
        }, org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "encounterDate"));
    }
    long countByEncounterDateBetweenAndEstado(Instant from,Instant to,ClinicalStatus status);
}
