package pe.com.dentalamericana.user;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.Collection;
import java.util.List;

public interface RoleRepository extends JpaRepository<Role, Long> {
    Optional<Role> findByCode(RoleCode code);
    List<Role> findAllByCodeIn(Collection<RoleCode> codes);
}
