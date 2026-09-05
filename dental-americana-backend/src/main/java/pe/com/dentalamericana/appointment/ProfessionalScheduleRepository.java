package pe.com.dentalamericana.appointment;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ProfessionalScheduleRepository extends JpaRepository<ProfessionalSchedule, Long> {
    List<ProfessionalSchedule> findAllByProfessionalIdAndDayOfWeekAndActivoTrueOrderByStartTimeAsc(Long professionalId, int dayOfWeek);
}
