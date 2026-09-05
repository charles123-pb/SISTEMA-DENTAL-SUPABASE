package pe.com.dentalamericana.user;

import java.util.List;

public record RoleResponse(String code, String name, String description, List<String> permissions) {
    public static RoleResponse from(Role role) {
        return new RoleResponse(role.getCode().name(), role.getName(), role.getDescription(),
                role.getPermissions().stream().map(permission -> permission.getCode().name()).sorted().toList());
    }
}
