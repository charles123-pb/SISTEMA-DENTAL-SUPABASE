package pe.com.dentalamericana.auth;

public record LoginResponse(
        String accessToken,
        String tokenType,
        long expiresInSeconds,
        CurrentUserResponse user
) {}
