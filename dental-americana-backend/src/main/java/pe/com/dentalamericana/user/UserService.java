package pe.com.dentalamericana.user;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
public class UserService {
    private final AppUserRepository users;
    private final RoleRepository roles;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    public UserService(AppUserRepository users, RoleRepository roles, PasswordEncoder passwordEncoder,
                       AuditService auditService) {
        this.users = users;
        this.roles = roles;
        this.passwordEncoder = passwordEncoder;
        this.auditService = auditService;
    }

    @Transactional(readOnly = true)
    public List<UserResponse> listUsers() {
        return users.findAllByOrderByFullNameAsc().stream().map(UserResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<RoleResponse> listRoles() {
        return roles.findAll().stream().filter(Role::isActive).map(RoleResponse::from).toList();
    }

    @Transactional
    public UserResponse create(CreateUserRequest request, AuthenticatedUser actor, HttpServletRequest httpRequest) {
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        String email = normalizeEmail(request.email());
        if (users.existsByUsernameIgnoreCase(username)) throw new IllegalStateException("El nombre de usuario ya existe");
        if (email != null && users.existsByEmailIgnoreCase(email)) throw new IllegalStateException("El correo ya está registrado");
        if (!request.roles().equals(Set.of(RoleCode.ODONTOLOGO))) {
            throw new IllegalStateException("El sistema utiliza únicamente el rol ODONTOLOGO");
        }
        Role dentistRole = roles.findByCode(RoleCode.ODONTOLOGO)
                .filter(Role::isActive)
                .orElseThrow(() -> new IllegalStateException("El rol ODONTOLOGO no está activo"));

        AppUser user = new AppUser(username, passwordEncoder.encode(request.password()), request.fullName().trim());
        user.changeContact(request.fullName().trim(), email);
        user.replaceRoles(new LinkedHashSet<>(Set.of(dentistRole)));
        AppUser saved = users.save(user);
        auditService.record(findActor(actor), "CREAR_USUARIO", "USUARIO", saved.getId().toString(),
                AuditResult.EXITO, "Usuario creado: " + saved.getUsername(), httpRequest);
        return UserResponse.from(saved);
    }

    @Transactional
    public UserResponse changeStatus(Long id, ChangeUserStatusRequest request, AuthenticatedUser actor,
                                     HttpServletRequest httpRequest) {
        if (actor.getId().equals(id) && !request.active()) {
            throw new IllegalStateException("No puede desactivar su propio usuario");
        }
        AppUser user = users.findById(id).orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));
        user.changeActive(request.active());
        auditService.record(findActor(actor), request.active() ? "ACTIVAR_USUARIO" : "DESACTIVAR_USUARIO",
                "USUARIO", id.toString(), AuditResult.EXITO, null, httpRequest);
        return UserResponse.from(user);
    }

    private AppUser findActor(AuthenticatedUser actor) {
        return users.findById(actor.getId()).orElse(null);
    }

    private String normalizeEmail(String email) {
        return email == null || email.isBlank() ? null : email.trim().toLowerCase(Locale.ROOT);
    }
}
