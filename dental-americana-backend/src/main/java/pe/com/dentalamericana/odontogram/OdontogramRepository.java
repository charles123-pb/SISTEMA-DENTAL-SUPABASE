package pe.com.dentalamericana.odontogram;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
public interface OdontogramRepository extends JpaRepository<Odontogram,Long>{
    Optional<Odontogram> findByEncounterIdAndDentitionType(Long encounterId,DentitionType type);
    List<Odontogram> findAllByEncounterIdOrderByDentitionType(Long encounterId);
}
