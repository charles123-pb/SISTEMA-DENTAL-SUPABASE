package pe.com.dentalamericana.auth;

import org.springframework.security.core.GrantedAuthority;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.util.List;

public record CurrentUserResponse(
        Long id,
        String username,
        String fullName,
        List<String> roles,
        List<String> permissions
) {
    public static CurrentUserResponse from(AuthenticatedUser user) {
        List<String> authorities = user.getAuthorities().stream().map(GrantedAuthority::getAuthority).sorted().toList();
        List<String> roles = authorities.stream().filter(value -> value.startsWith("ROLE_"))
                .map(value -> value.substring(5)).toList();
        List<String> permissions = authorities.stream().filter(value -> !value.startsWith("ROLE_")).toList();
        return new CurrentUserResponse(user.getId(), user.getUsername(), user.getFullName(), roles, permissions);
    }
}
