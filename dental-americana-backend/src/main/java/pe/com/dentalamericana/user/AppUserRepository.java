package pe.com.dentalamericana.user;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.util.Optional;
import java.util.List;

public interface AppUserRepository extends JpaRepository<AppUser, Long> {
    Optional<AppUser> findByUsernameIgnoreCase(String username);
    boolean existsByUsernameIgnoreCase(String username);
    boolean existsByEmailIgnoreCase(String email);
    List<AppUser> findAllByOrderByFullNameAsc();

    @Query("select distinct u from AppUser u join u.roles r where u.active = true and u.locked = false and r.code = pe.com.dentalamericana.user.RoleCode.ODONTOLOGO order by u.fullName")
    List<AppUser> findActiveDentists();
}
