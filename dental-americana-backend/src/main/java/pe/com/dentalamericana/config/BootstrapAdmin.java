package pe.com.dentalamericana.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.user.*;

import java.util.Locale;

@Component
public class BootstrapAdmin implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(BootstrapAdmin.class);
    private final AppUserRepository users;
    private final RoleRepository roles;
    private final PasswordEncoder passwordEncoder;
    private final boolean enabled;
    private final String username;
    private final String password;
    private final String fullName;

    public BootstrapAdmin(AppUserRepository users, RoleRepository roles, PasswordEncoder passwordEncoder,
                          @Value("${app.bootstrap-admin.enabled}") boolean enabled,
                          @Value("${app.bootstrap-admin.username}") String username,
                          @Value("${app.bootstrap-admin.password}") String password,
                          @Value("${app.bootstrap-admin.full-name}") String fullName) {
        this.users = users;
        this.roles = roles;
        this.passwordEncoder = passwordEncoder;
        this.enabled = enabled;
        this.username = username;
        this.password = password;
        this.fullName = fullName;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!enabled || username.isBlank() || password.isBlank()) return;
        String normalizedUsername = username.trim().toLowerCase(Locale.ROOT);
        if (users.existsByUsernameIgnoreCase(normalizedUsername)) return;
        Role administrator = roles.findByCode(RoleCode.ODONTOLOGO)
                .orElseThrow(() -> new IllegalStateException("No se encontró el rol ODONTOLOGO"));
        AppUser user = new AppUser(normalizedUsername, passwordEncoder.encode(password), fullName.trim());
        user.assignRole(administrator);
        users.save(user);
        log.warn("Usuario odontólogo inicial creado. Cambie la contraseña antes de publicar el sistema.");
    }
}
