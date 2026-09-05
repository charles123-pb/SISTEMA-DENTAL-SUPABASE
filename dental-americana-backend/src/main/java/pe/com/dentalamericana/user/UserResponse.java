package pe.com.dentalamericana.user;

import java.time.Instant;
import java.util.List;

public record UserResponse(
        Long id,
        String username,
        String fullName,
        String email,
        boolean active,
        boolean locked,
        Instant lastAccess,
        List<String> roles
) {
    public static UserResponse from(AppUser user) {
        return new UserResponse(user.getId(), user.getUsername(), user.getFullName(), user.getEmail(),
                user.isActive(), user.isLocked(), user.getLastAccess(),
                user.getRoles().stream().map(role -> role.getCode().name()).sorted().toList());
    }
}
