package pe.com.dentalamericana.appointment;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface AppointmentTypeRepository extends JpaRepository<AppointmentType, Long> {
    List<AppointmentType> findAllByActivoTrueOrderByNombreAsc();
}
