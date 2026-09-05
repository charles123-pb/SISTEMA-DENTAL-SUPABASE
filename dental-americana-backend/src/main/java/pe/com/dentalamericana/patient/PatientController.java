package pe.com.dentalamericana.patient;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import pe.com.dentalamericana.patient.dto.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {
    private final PatientService service;

    public PatientController(PatientService service) { this.service = service; }

    @GetMapping
    @PreAuthorize("hasAuthority('PACIENTE_LEER')")
    public PageResponse<PatientSummaryResponse> search(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Boolean active,
            @RequestParam(required = false) Sex sex,
            @RequestParam(required = false) Integer minAge,
            @RequestParam(required = false) Integer maxAge,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate registeredFrom,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate registeredTo,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "fullName") String sort,
            @RequestParam(defaultValue = "asc") String direction) {
        return service.search(q, active, sex, minAge, maxAge, registeredFrom, registeredTo,
                page, size, sort, direction);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('PACIENTE_LEER')")
    public PatientDetailResponse get(@PathVariable Long id) { return service.get(id); }

    @GetMapping("/duplicates")
    @PreAuthorize("hasAuthority('PACIENTE_LEER')")
    public List<DuplicateCandidateResponse> duplicates(
            @RequestParam(required = false) String documentNumber,
            @RequestParam(required = false) String mobile,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate birthDate,
            @RequestParam(required = false) String paternalSurname) {
        return service.duplicates(documentNumber, mobile, birthDate, paternalSurname);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('PACIENTE_ESCRIBIR')")
    public PatientDetailResponse create(@Valid @RequestBody CreatePatientRequest request,
                                        @AuthenticationPrincipal AuthenticatedUser actor,
                                        HttpServletRequest httpRequest) {
        return service.create(request, actor, httpRequest);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PACIENTE_ESCRIBIR')")
    public PatientDetailResponse update(@PathVariable Long id, @Valid @RequestBody UpdatePatientRequest request,
                                        @AuthenticationPrincipal AuthenticatedUser actor,
                                        HttpServletRequest httpRequest) {
        return service.update(id, request, actor, httpRequest);
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority('PACIENTE_ESCRIBIR')")
    public PatientDetailResponse status(@PathVariable Long id, @Valid @RequestBody PatientStatusRequest request,
                                        @AuthenticationPrincipal AuthenticatedUser actor,
                                        HttpServletRequest httpRequest) {
        return service.changeStatus(id, request, actor, httpRequest);
    }
}
