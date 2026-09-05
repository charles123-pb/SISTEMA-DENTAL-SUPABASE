package pe.com.dentalamericana.clinical;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import pe.com.dentalamericana.clinical.dto.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/v1/clinical-encounters")
public class ClinicalEncounterController {
    private final ClinicalEncounterService service;
    public ClinicalEncounterController(ClinicalEncounterService service) { this.service = service; }

    @GetMapping
    @PreAuthorize("hasAuthority('CLINICA_LEER')")
    public List<ClinicalEncounterResponse> search(@RequestParam(required = false) Instant from,
                                                  @RequestParam(required = false) Instant to,
                                                  @RequestParam(required = false) ClinicalStatus status,
                                                  @RequestParam(required = false) Long patientId) {
        return service.search(from, to, status, patientId);
    }
    @GetMapping("/{id}") @PreAuthorize("hasAuthority('CLINICA_LEER')")
    public ClinicalEncounterResponse get(@PathVariable Long id) { return service.get(id); }

    @PostMapping @ResponseStatus(HttpStatus.CREATED) @PreAuthorize("hasAuthority('CLINICA_ESCRIBIR')")
    public ClinicalEncounterResponse start(@Valid @RequestBody StartEncounterRequest request,
                                           @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.start(request, actor, httpRequest);
    }
    @PutMapping("/{id}") @PreAuthorize("hasAuthority('CLINICA_ESCRIBIR')")
    public ClinicalEncounterResponse update(@PathVariable Long id, @Valid @RequestBody ClinicalEncounterRequest request,
                                            @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.update(id, request, actor, httpRequest);
    }
    @PostMapping("/{id}/finalize") @PreAuthorize("hasAuthority('CLINICA_APROBAR')")
    public ClinicalEncounterResponse finalizeEncounter(@PathVariable Long id, @Valid @RequestBody FinalizeEncounterRequest request,
                                                       @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.finalizeEncounter(id, request, actor, httpRequest);
    }
}
