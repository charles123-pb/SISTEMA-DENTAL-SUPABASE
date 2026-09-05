package pe.com.dentalamericana.auth;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ChangePasswordRequest(
        @NotBlank String currentPassword,
        @NotBlank
        @Size(min = 10, max = 72, message = "La nueva contraseña debe tener entre 10 y 72 caracteres")
        @Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).+$",
                message = "Use al menos una mayúscula, una minúscula y un número")
        String newPassword,
        @NotBlank String confirmation
) {
    @AssertTrue(message = "La confirmación de contraseña no coincide")
    public boolean isConfirmationValid() {
        return newPassword != null && newPassword.equals(confirmation);
    }
}
