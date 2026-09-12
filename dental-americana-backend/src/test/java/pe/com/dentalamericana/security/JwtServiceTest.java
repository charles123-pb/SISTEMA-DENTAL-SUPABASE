package pe.com.dentalamericana.security;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import pe.com.dentalamericana.user.AppUser;
import pe.com.dentalamericana.user.PermissionCode;
import pe.com.dentalamericana.user.RoleCode;

import java.lang.reflect.Constructor;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class JwtServiceTest {
    private static final String SECRET = "ZGVudGFsLWFtZXJpY2FuYS10ZXN0LXNlY3JldC0yMDI2LXNlZ3Vybw==";

    @Test
    void generatesAndValidatesToken() throws Exception {
        JwtService service = new JwtService(SECRET, 60);
        AuthenticatedUser user = authenticatedUser();

        String token = service.generateToken(user);

        assertEquals("doctor", service.extractUsername(token));
        assertTrue(service.isValid(token, user));
        assertEquals(3600, service.getExpirationSeconds());
    }

    @Test
    void rejectsTokenForDifferentUser() throws Exception {
        JwtService service = new JwtService(SECRET, 60);
        String token = service.generateToken(authenticatedUser());
        assertFalse(service.isValid(token, authenticatedUser("otro")));
    }

    private AuthenticatedUser authenticatedUser() throws Exception { return authenticatedUser("doctor"); }

    @Test
    void passwordChangeInvalidatesExistingToken() throws Exception {
        JwtService service = new JwtService(SECRET, 60);
        AppUser entity = new AppUser("doctor", "hash-original", "Doctor de prueba");
        String token = service.generateToken(AuthenticatedUser.from(entity));
        entity.changePassword("hash-nuevo");
        assertFalse(service.isValid(token, AuthenticatedUser.from(entity)));
    }

    @Test
    void deactivationInvalidatesExistingToken() {
        JwtService service = new JwtService(SECRET, 60);
        AppUser entity = new AppUser("doctor", "hash", "Doctor de prueba");
        String token = service.generateToken(AuthenticatedUser.from(entity));
        entity.changeActive(false);
        assertFalse(service.isValid(token, AuthenticatedUser.from(entity)));
    }

    private AuthenticatedUser authenticatedUser(String username) throws Exception {
        Constructor<AuthenticatedUser> constructor = AuthenticatedUser.class.getDeclaredConstructor(
                Long.class, String.class, String.class, String.class, boolean.class, boolean.class, Set.class);
        constructor.setAccessible(true);
        return constructor.newInstance(1L, username, "hash", "Doctor de prueba", true, false,
                Set.of(new SimpleGrantedAuthority("ROLE_" + RoleCode.ODONTOLOGO.name()),
                        new SimpleGrantedAuthority(PermissionCode.CLINICA_LEER.name())));
    }
}
