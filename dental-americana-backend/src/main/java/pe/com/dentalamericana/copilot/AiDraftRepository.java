package pe.com.dentalamericana.copilot;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface AiDraftRepository extends JpaRepository<AiDraft,Long>{List<AiDraft>findAllByEncounterIdOrderByGeneratedAtDesc(Long encounterId);}
