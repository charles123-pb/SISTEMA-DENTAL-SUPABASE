package pe.com.dentalamericana.appointment;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Collection;

public interface AppointmentRepository extends JpaRepository<Appointment, Long> {
    @Query("""
        select a from Appointment a
        where a.inicio < :end and a.fin > :start
          and (:professionalId is null or a.professionalId = :professionalId)
          and (:status is null or a.estado = :status)
        order by a.inicio asc
        """)
    List<Appointment> search(@Param("start") Instant start, @Param("end") Instant end,
                             @Param("professionalId") Long professionalId, @Param("status") AppointmentStatus status);

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
    List<Appointment> findTop50ByReminderScheduledFalseAndInicioBetweenAndEstadoInOrderByInicioAsc(
            Instant from, Instant to, Collection<AppointmentStatus> statuses);
    long countByInicioBetween(Instant from,Instant to);
    long countByInicioBetweenAndEstado(Instant from,Instant to,AppointmentStatus status);
}
