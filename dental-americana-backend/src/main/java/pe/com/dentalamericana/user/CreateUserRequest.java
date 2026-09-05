package pe.com.dentalamericana.user;

import jakarta.validation.constraints.*;
import java.util.Set;

public record CreateUserRequest(
        @NotBlank @Pattern(regexp = "^[a-zA-Z0-9._-]{4,60}$", message = "Use entre 4 y 60 letras, números, punto, guion o guion bajo") String username,
        @NotBlank @Size(min = 10, max = 72, message = "La contraseña debe tener entre 10 y 72 caracteres") String password,
        @NotBlank @Size(max = 150) String fullName,
        @Email @Size(max = 150) String email,
        @NotEmpty(message = "Seleccione al menos un rol") Set<RoleCode> roles
) {}
