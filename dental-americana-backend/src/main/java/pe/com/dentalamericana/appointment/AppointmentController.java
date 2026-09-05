package pe.com.dentalamericana.appointment;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import pe.com.dentalamericana.appointment.dto.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class AppointmentController {
    private final AppointmentService service;
    public AppointmentController(AppointmentService service) { this.service = service; }

    @GetMapping("/appointment-types")
    @PreAuthorize("hasAuthority('CITA_LEER')")
    public List<AppointmentTypeResponse> types() { return service.listTypes(); }

    @GetMapping("/appointments/professionals")
    @PreAuthorize("hasAuthority('CITA_LEER')")
    public List<ProfessionalResponse> professionals() { return service.listProfessionals(); }

    @GetMapping("/appointments")
    @PreAuthorize("hasAuthority('CITA_LEER')")
    public List<AppointmentResponse> search(@RequestParam Instant from, @RequestParam Instant to,
                                            @RequestParam(required = false) Long professionalId,
                                            @RequestParam(required = false) AppointmentStatus status) {
        return service.search(from, to, professionalId, status);
    }

    @GetMapping("/appointments/{id}")
    @PreAuthorize("hasAuthority('CITA_LEER')")
    public AppointmentResponse get(@PathVariable Long id) { return service.get(id); }

    @GetMapping("/appointments/availability")
    @PreAuthorize("hasAuthority('CITA_LEER')")
    public List<AvailabilitySlotResponse> availability(@RequestParam Long professionalId,
                                                       @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                                       @RequestParam Long appointmentTypeId) {
        return service.availability(professionalId, date, appointmentTypeId);
    }

    @PostMapping("/appointments")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('CITA_ESCRIBIR')")
    public AppointmentResponse create(@Valid @RequestBody AppointmentRequest request,
                                      @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.create(request, actor, httpRequest);
    }

    @PutMapping("/appointments/{id}")
    @PreAuthorize("hasAuthority('CITA_ESCRIBIR')")
    public AppointmentResponse update(@PathVariable Long id, @Valid @RequestBody AppointmentRequest request,
                                      @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.update(id, request, actor, httpRequest);
    }

    @PatchMapping("/appointments/{id}/status")
    @PreAuthorize("hasAuthority('CITA_ESCRIBIR')")
    public AppointmentResponse status(@PathVariable Long id, @Valid @RequestBody AppointmentStatusRequest request,
                                      @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.changeStatus(id, request, actor, httpRequest);
    }
}
