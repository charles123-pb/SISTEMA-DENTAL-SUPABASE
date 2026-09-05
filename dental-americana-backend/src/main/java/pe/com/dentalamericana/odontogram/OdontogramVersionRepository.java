package pe.com.dentalamericana.odontogram;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface OdontogramVersionRepository extends JpaRepository<OdontogramVersion, Long> {
    Optional<OdontogramVersion> findTopByOdontogramIdOrderByVersionNumberDesc(Long odontogramId);
}
