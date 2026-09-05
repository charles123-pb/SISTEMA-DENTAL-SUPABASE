package pe.com.dentalamericana.user;

import jakarta.validation.constraints.NotNull;

public record ChangeUserStatusRequest(@NotNull Boolean active) {}
