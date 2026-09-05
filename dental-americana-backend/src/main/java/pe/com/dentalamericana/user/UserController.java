package pe.com.dentalamericana.user;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class UserController {
    private final UserService userService;

    public UserController(UserService userService) { this.userService = userService; }

    @GetMapping("/users")
    @PreAuthorize("hasAuthority('USUARIO_LEER')")
    public List<UserResponse> listUsers() { return userService.listUsers(); }

    @GetMapping("/roles")
    @PreAuthorize("hasAuthority('USUARIO_LEER')")
    public List<RoleResponse> listRoles() { return userService.listRoles(); }

    @PostMapping("/users")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('USUARIO_ESCRIBIR')")
    public UserResponse create(@Valid @RequestBody CreateUserRequest request,
                               @AuthenticationPrincipal AuthenticatedUser actor,
                               HttpServletRequest httpRequest) {
        return userService.create(request, actor, httpRequest);
    }

    @PatchMapping("/users/{id}/status")
    @PreAuthorize("hasAuthority('USUARIO_ESCRIBIR')")
    public UserResponse changeStatus(@PathVariable Long id,
                                     @Valid @RequestBody ChangeUserStatusRequest request,
                                     @AuthenticationPrincipal AuthenticatedUser actor,
                                     HttpServletRequest httpRequest) {
        return userService.changeStatus(id, request, actor, httpRequest);
    }
}
