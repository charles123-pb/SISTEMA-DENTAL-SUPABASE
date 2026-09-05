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

    @Query("""
            select p from Patient p
            where (:documentNumber is not null and lower(p.documentNumber) = lower(:documentNumber))
               or (:mobile is not null and p.celular = :mobile)
               or (:birthDate is not null and :paternalSurname is not null
                   and p.birthDate = :birthDate and lower(p.paternalSurname) = lower(:paternalSurname))
            order by p.updatedAt desc
            """)
    List<Patient> findDuplicateCandidates(@Param("documentNumber") String documentNumber,
                                          @Param("mobile") String mobile,
                                          @Param("birthDate") LocalDate birthDate,
                                          @Param("paternalSurname") String paternalSurname);
}
