package pe.com.dentalamericana.appointment;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.List;

public interface ScheduleBlockRepository extends JpaRepository<ScheduleBlock, Long> {
    @Query("select b from ScheduleBlock b where b.professionalId = :professionalId and b.activo = true and b.inicio < :end and b.fin > :start")
    List<ScheduleBlock> findOverlapping(@Param("professionalId") Long professionalId,
                                        @Param("start") Instant start, @Param("end") Instant end);
}
