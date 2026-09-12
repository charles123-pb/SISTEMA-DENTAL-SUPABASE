package pe.com.dentalamericana.copilot;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import pe.com.dentalamericana.copilot.dto.CopilotDtos.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

@RestController
@RequestMapping("/api/v1/copilot/drafts")
public class CopilotEditController {
    private final CopilotService service;
    public CopilotEditController(CopilotService service) { this.service = service; }
    @PatchMapping("/{id}/content")
    @PreAuthorize("hasAuthority('IA_ESCRIBIR')")
    public DraftResponse edit(@PathVariable Long id, @Valid @RequestBody EditDraftRequest request,
                              @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest http) {
        return service.edit(id, request, actor, http);
    }
}
