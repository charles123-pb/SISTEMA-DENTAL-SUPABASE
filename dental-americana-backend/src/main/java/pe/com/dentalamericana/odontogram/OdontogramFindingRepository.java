package pe.com.dentalamericana.odontogram;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
public interface OdontogramFindingRepository extends JpaRepository<OdontogramFinding,Long>{
    List<OdontogramFinding> findAllByOdontogramIdAndActivoTrueOrderByPiezaAscSuperficieAsc(Long odontogramId);
    Optional<OdontogramFinding> findByOdontogramIdAndPiezaAndSuperficieAndCondicionAndActivoTrue(Long odontogramId,String tooth,ToothSurface surface,ToothCondition condition);
    Optional<OdontogramFinding> findByIdAndOdontogramIdAndActivoTrue(Long id,Long odontogramId);
}
