package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface PatientRepository extends JpaRepository<Patient, Long>, JpaSpecificationExecutor<Patient> {
    @Query(value = "select nextval('patient_history_number_seq')", nativeQuery = true)
    Long nextHistorySequence();

    boolean existsByDocumentNumberIgnoreCase(String documentNumber);
    boolean existsByDocumentNumberIgnoreCaseAndIdNot(String documentNumber, Long id);
    Optional<Patient> findFirstByCelular(String mobile);
    Optional<Patient> findFirstByCelularIn(List<String> mobiles);
    List<Patient> findAllByCelularIn(List<String> mobiles);

    default List<Patient> findDuplicateCandidates(String documentNumber, String mobile,
                                                  LocalDate birthDate, String paternalSurname) {
        return findAll((root, query, cb) -> {
            var alternatives = new java.util.ArrayList<jakarta.persistence.criteria.Predicate>();
            if (documentNumber != null) alternatives.add(cb.equal(cb.lower(root.get("documentNumber")), documentNumber.toLowerCase(java.util.Locale.ROOT)));
            if (mobile != null) {
                var candidates = new java.util.ArrayList<String>();
                candidates.add(mobile);
                if (mobile.length() == 9) candidates.add("51" + mobile);
                if (mobile.startsWith("51") && mobile.length() == 11) candidates.add(mobile.substring(2));
                alternatives.add(root.get("celular").in(candidates));
            }
            if (birthDate != null && paternalSurname != null) alternatives.add(cb.and(
                    cb.equal(root.get("birthDate"), birthDate),
                    cb.equal(cb.lower(root.get("paternalSurname")), paternalSurname.toLowerCase(java.util.Locale.ROOT))));
            return cb.or(alternatives.toArray(jakarta.persistence.criteria.Predicate[]::new));
        }, org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "updatedAt"));
    }
}
