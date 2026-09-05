package pe.com.dentalamericana.patient;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import pe.com.dentalamericana.patient.dto.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

@RestController
@RequestMapping("/api/v1/patients/{patientId}")
public class PatientClinicalDataController {
    private final PatientClinicalDataService service;

    public PatientClinicalDataController(PatientClinicalDataService service) { this.service = service; }

    @PostMapping("/emergency-contacts")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('PACIENTE_ESCRIBIR')")
    public EmergencyContactResponse contact(@PathVariable Long patientId, @Valid @RequestBody EmergencyContactRequest request,
                                            @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.addContact(patientId, request, actor, httpRequest);
    }

    @PostMapping("/histories")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('CLINICA_ESCRIBIR')")
    public HistoryResponse history(@PathVariable Long patientId, @Valid @RequestBody HistoryRequest request,
                                   @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.addHistory(patientId, request, actor, httpRequest);
    }

    @PostMapping("/allergies")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('CLINICA_ESCRIBIR')")
    public AllergyResponse allergy(@PathVariable Long patientId, @Valid @RequestBody AllergyRequest request,
                                   @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.addAllergy(patientId, request, actor, httpRequest);
    }

    @PostMapping("/medications")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('CLINICA_ESCRIBIR')")
    public MedicationResponse medication(@PathVariable Long patientId, @Valid @RequestBody MedicationRequest request,
                                         @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest httpRequest) {
        return service.addMedication(patientId, request, actor, httpRequest);
    }
}
