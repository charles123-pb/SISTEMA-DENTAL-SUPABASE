package pe.com.dentalamericana.appointment;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Collection;

public interface AppointmentRepository extends JpaRepository<Appointment, Long>, org.springframework.data.jpa.repository.JpaSpecificationExecutor<Appointment> {
    default List<Appointment> search(Instant start, Instant end, Long professionalId, AppointmentStatus status) {
        return findAll((root, query, cb) -> {
            var filters = new java.util.ArrayList<jakarta.persistence.criteria.Predicate>();
            filters.add(cb.lessThan(root.get("inicio"), end));
            filters.add(cb.greaterThan(root.get("fin"), start));
            if (professionalId != null) filters.add(cb.equal(root.get("professionalId"), professionalId));
            if (status != null) filters.add(cb.equal(root.get("estado"), status));
            return cb.and(filters.toArray(jakarta.persistence.criteria.Predicate[]::new));
        }, org.springframework.data.domain.Sort.by("inicio"));
    }

    List<Appointment> findAllByPatientIdAndInicioAfterAndEstadoInOrderByInicioAsc(Long patientId, Instant now, Collection<AppointmentStatus> statuses);

    @Query("select count(e) > 0 from ClinicalEncounter e where e.appointmentId = :appointmentId")
    boolean hasClinicalEncounter(@Param("appointmentId") Long appointmentId);

    @Query("""
        select count(a) from Appointment a
        where a.professionalId = :professionalId and a.id <> :excludedId
          and a.estado not in (pe.com.dentalamericana.appointment.AppointmentStatus.CANCELADA,
                               pe.com.dentalamericana.appointment.AppointmentStatus.NO_ASISTIO)
          and a.inicio < :end and a.fin > :start
        """)
    long countProfessionalConflicts(@Param("professionalId") Long professionalId,
                                    @Param("start") Instant start, @Param("end") Instant end,
                                    @Param("excludedId") Long excludedId);

    @Query("""
        select count(a) from Appointment a
        where a.patientId = :patientId and a.id <> :excludedId
          and a.estado not in (pe.com.dentalamericana.appointment.AppointmentStatus.CANCELADA,
                               pe.com.dentalamericana.appointment.AppointmentStatus.NO_ASISTIO)
          and a.inicio < :end and a.fin > :start
        """)
    long countPatientConflicts(@Param("patientId") Long patientId,
                               @Param("start") Instant start, @Param("end") Instant end,
                               @Param("excludedId") Long excludedId);

    Optional<Appointment> findFirstByPatientIdAndInicioAfterAndEstadoOrderByInicioAsc(Long patientId, Instant now, AppointmentStatus status);
    Optional<Appointment> findFirstByPatientIdAndInicioAfterAndEstadoInOrderByInicioAsc(
            Long patientId, Instant now, Collection<AppointmentStatus> statuses);
    List<Appointment> findTop50ByReminderScheduledFalseAndInicioBetweenAndEstadoInOrderByInicioAsc(
            Instant from, Instant to, Collection<AppointmentStatus> statuses);
    long countByInicioBetween(Instant from,Instant to);
    long countByInicioBetweenAndEstado(Instant from,Instant to,AppointmentStatus status);
}
