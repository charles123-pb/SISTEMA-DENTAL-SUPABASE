package pe.com.dentalamericana.auth;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.security.JwtService;
import pe.com.dentalamericana.user.AppUser;
import pe.com.dentalamericana.user.AppUserRepository;

import java.util.Locale;

@Service
public class AuthService {
    private final AuthenticationManager authenticationManager;
    private final AppUserRepository users;
    private final JwtService jwtService;
    private final AuditService auditService;
    private final PasswordEncoder passwordEncoder;

    public AuthService(AuthenticationManager authenticationManager, AppUserRepository users,
                       JwtService jwtService, AuditService auditService, PasswordEncoder passwordEncoder) {
        this.authenticationManager = authenticationManager;
        this.users = users;
        this.jwtService = jwtService;
        this.auditService = auditService;
        this.passwordEncoder = passwordEncoder;
    }

    public LoginResponse login(LoginRequest request, HttpServletRequest httpRequest) {
        String username = request.username().trim().toLowerCase(Locale.ROOT);
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(username, request.password()));
            AuthenticatedUser principal = (AuthenticatedUser) authentication.getPrincipal();
            AppUser user = users.findByUsernameIgnoreCase(username).orElseThrow();
            user.registerSuccessfulAccess();
            users.save(user);
            auditService.record(user, "INICIAR_SESION", "SEGURIDAD", null, AuditResult.EXITO,
                    "Inicio de sesión correcto", httpRequest);
            String token = jwtService.generateToken(principal);
            return new LoginResponse(token, "Bearer", jwtService.getExpirationSeconds(), CurrentUserResponse.from(principal));
        } catch (AuthenticationException exception) {
            AppUser user = users.findByUsernameIgnoreCase(username).orElse(null);
            if (user != null) {
                user.registerFailedAttempt();
                users.save(user);
            }
            auditService.record(user, "INICIAR_SESION", "SEGURIDAD", null, AuditResult.DENEGADO,
                    "Credenciales inválidas", httpRequest);
            throw new BadCredentialsException("Credenciales inválidas");
        }
    }

    @Transactional
    public void changePassword(ChangePasswordRequest request, AuthenticatedUser actor,
                               HttpServletRequest httpRequest) {
        AppUser user = users.findById(actor.getId()).orElseThrow();
        if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
            auditService.record(user, "CAMBIAR_CONTRASENA", "SEGURIDAD", user.getId().toString(),
                    AuditResult.DENEGADO, "Contraseña actual incorrecta", httpRequest);
            throw new BadCredentialsException("Contraseña actual incorrecta");
        }
        if (passwordEncoder.matches(request.newPassword(), user.getPasswordHash())) {
            throw new IllegalStateException("La nueva contraseña debe ser diferente de la actual");
        }
        user.changePassword(passwordEncoder.encode(request.newPassword()));
        auditService.record(user, "CAMBIAR_CONTRASENA", "SEGURIDAD", user.getId().toString(),
                AuditResult.EXITO, "Contraseña actualizada por el usuario", httpRequest);
    }
}
