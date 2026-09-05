package pe.com.dentalamericana.odontogram;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.clinical.ClinicalEncounter;
import pe.com.dentalamericana.clinical.ClinicalEncounterRepository;
import pe.com.dentalamericana.clinical.ClinicalStatus;
import pe.com.dentalamericana.common.BusinessConflictException;
import pe.com.dentalamericana.common.ResourceNotFoundException;
import pe.com.dentalamericana.odontogram.dto.*;
import pe.com.dentalamericana.patient.PatientService;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.user.AppUser;
import pe.com.dentalamericana.user.AppUserRepository;
import pe.com.dentalamericana.user.RoleCode;

import java.util.List;
import java.util.Optional;
import java.util.Set;

@Service
public class OdontogramService {
    private static final Set<String> PERMANENT = Set.of(
            "18", "17", "16", "15", "14", "13", "12", "11",
            "21", "22", "23", "24", "25", "26", "27", "28",
            "48", "47", "46", "45", "44", "43", "42", "41",
            "31", "32", "33", "34", "35", "36", "37", "38");
    private static final Set<String> PRIMARY = Set.of(
            "55", "54", "53", "52", "51", "61", "62", "63", "64", "65",
            "85", "84", "83", "82", "81", "71", "72", "73", "74", "75");

    private final OdontogramRepository odontograms;
    private final OdontogramFindingRepository findings;
    private final OdontogramVersionRepository versions;
    private final ClinicalEncounterRepository encounters;
    private final AppUserRepository users;
    private final PatientService patients;
    private final AuditService audit;
    private final ObjectMapper objectMapper;

    public OdontogramService(OdontogramRepository odontograms,
                             OdontogramFindingRepository findings,
                             OdontogramVersionRepository versions,
                             ClinicalEncounterRepository encounters,
                             AppUserRepository users,
                             PatientService patients,
                             AuditService audit,
                             ObjectMapper objectMapper) {
        this.odontograms = odontograms;
        this.findings = findings;
        this.versions = versions;
        this.encounters = encounters;
        this.users = users;
        this.patients = patients;
        this.audit = audit;
        this.objectMapper = objectMapper;
    }

    @Transactional(readOnly = true)
    public List<OdontogramResponse> list(Long encounterId) {
        requireEncounter(encounterId);
        return odontograms.findAllByEncounterIdOrderByDentitionType(encounterId)
                .stream().map(this::response).toList();
    }

    @Transactional
    public OdontogramResponse initialize(Long encounterId, OdontogramRequest request,
                                         AuthenticatedUser actor, HttpServletRequest http) {
        ClinicalEncounter encounter = requireEditable(encounterId, actor);
        Optional<Odontogram> existing = odontograms
                .findByEncounterIdAndDentitionType(encounterId, request.dentitionType());
        if (existing.isPresent()) return response(existing.get());

        Odontogram saved = odontograms.saveAndFlush(new Odontogram(
                encounterId, encounter.getPatientId(), request.dentitionType(), actor.getId()));
        if (request.generalObservation() != null && !request.generalObservation().isBlank()) {
            saved.observe(request.generalObservation().trim(), actor.getId());
            odontograms.flush();
        }
        saveSnapshot(saved, "Odontograma creado", actor.getId());
        record(actor, "CREAR_ODONTOGRAMA", saved.getId(), request.dentitionType().name(), http);
        return response(saved);
    }

    @Transactional
    public OdontogramResponse observe(Long id, OdontogramObservationRequest request,
                                      AuthenticatedUser actor, HttpServletRequest http) {
        Odontogram item = find(id);
        requireEditable(item.getEncounterId(), actor);
        requireDraftVersion(item, request.version());
        item.observe(trim(request.generalObservation()), actor.getId());
        odontograms.flush();
        saveSnapshot(item, "Observación general actualizada", actor.getId());
        record(actor, "ACTUALIZAR_ODONTOGRAMA", id, "Observación general", http);
        return response(item);
    }

    @Transactional
    public OdontogramResponse addFinding(Long id, FindingRequest request,
                                         AuthenticatedUser actor, HttpServletRequest http) {
        Odontogram item = find(id);
        requireEditable(item.getEncounterId(), actor);
        if (item.getStatus() != OdontogramStatus.BORRADOR) {
            throw new BusinessConflictException("El odontograma ya fue aprobado");
        }
        validateTooth(item.getDentitionType(), request.tooth());
        findings.findByOdontogramIdAndPiezaAndSuperficieAndCondicionAndActivoTrue(
                        id, request.tooth(), request.surface(), request.condition())
                .ifPresentOrElse(
                        existing -> existing.revise(request.treatmentState(),
                                trim(request.observation()), actor.getId()),
                        () -> findings.save(new OdontogramFinding(id, request.tooth(),
                                request.surface(), request.condition(), request.treatmentState(),
                                trim(request.observation()), actor.getId())));
        findings.flush();
        item.touch(actor.getId());
        odontograms.flush();
        saveSnapshot(item, "Hallazgo registrado en pieza " + request.tooth(), actor.getId());
        record(actor, "REGISTRAR_HALLAZGO_ODONTOGRAMA", id,
                "Pieza " + request.tooth() + ", " + request.condition(), http);
        return response(item);
    }

    @Transactional
    public OdontogramResponse removeFinding(Long id, Long findingId, FindingStatusRequest request,
                                            AuthenticatedUser actor, HttpServletRequest http) {
        Odontogram item = find(id);
        requireEditable(item.getEncounterId(), actor);
        if (item.getStatus() != OdontogramStatus.BORRADOR) {
            throw new BusinessConflictException("El odontograma ya fue aprobado");
        }
        OdontogramFinding finding = findings.findByIdAndOdontogramIdAndActivoTrue(findingId, id)
                .orElseThrow(() -> new ResourceNotFoundException("Hallazgo no encontrado"));
        if (!finding.getVersion().equals(request.version())) {
            throw new BusinessConflictException("El hallazgo fue modificado por otro usuario");
        }
        finding.deactivate(actor.getId());
        findings.flush();
        item.touch(actor.getId());
        odontograms.flush();
        saveSnapshot(item, "Hallazgo retirado de pieza " + finding.getTooth(), actor.getId());
        record(actor, "RETIRAR_HALLAZGO_ODONTOGRAMA", id, "Hallazgo " + findingId, http);
        return response(item);
    }

    @Transactional
    public OdontogramResponse approve(Long id, ApproveOdontogramRequest request,
                                      AuthenticatedUser actor, HttpServletRequest http) {
        Odontogram item = find(id);
        requireEditable(item.getEncounterId(), actor);
        requireDraftVersion(item, request.version());
        item.approve(actor.getId());
        odontograms.flush();
        saveSnapshot(item, "Odontograma aprobado por el profesional", actor.getId());
        record(actor, "APROBAR_ODONTOGRAMA", id, item.getDentitionType().name(), http);
        return response(item);
    }

    private OdontogramResponse response(Odontogram item) {
        return new OdontogramResponse(item.getId(), item.getEncounterId(), item.getPatientId(),
                item.getDentitionType(), item.getStatus(), item.getGeneralObservation(),
                item.getApprovedBy(), item.getApprovedAt(), item.getCreatedAt(), item.getUpdatedAt(),
                item.getVersion(), findings.findAllByOdontogramIdAndActivoTrueOrderByPiezaAscSuperficieAsc(
                        item.getId()).stream().map(OdontogramFindingResponse::from).toList());
    }

    private void saveSnapshot(Odontogram item, String summary, Long actorId) {
        try {
            long next = versions.findTopByOdontogramIdOrderByVersionNumberDesc(item.getId())
                    .map(previous -> previous.getVersionNumber() + 1).orElse(1L);
            versions.save(new OdontogramVersion(item.getId(), next, summary,
                    objectMapper.writeValueAsString(response(item)), actorId));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("No se pudo versionar el odontograma", exception);
        }
    }

    private ClinicalEncounter requireEncounter(Long id) {
        return encounters.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Atención no encontrada"));
    }

    private ClinicalEncounter requireEditable(Long id, AuthenticatedUser actor) {
        ClinicalEncounter encounter = requireEncounter(id);
        if (encounter.getStatus() != ClinicalStatus.BORRADOR) {
            throw new BusinessConflictException("La atención ya fue finalizada");
        }
        AppUser user = users.findById(actor.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));
        if (!user.isActive() || user.isLocked()
                || user.getRoles().stream().noneMatch(role -> role.getCode() == RoleCode.ODONTOLOGO)) {
            throw new BusinessConflictException("La acción requiere un odontólogo activo");
        }
        if (!encounter.getDentistId().equals(user.getId())) {
            throw new BusinessConflictException("Solo el odontólogo responsable puede modificar este odontograma");
        }
        return encounter;
    }

    private Odontogram find(Long id) {
        return odontograms.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Odontograma no encontrado"));
    }

    private void requireDraftVersion(Odontogram item, Long version) {
        if (item.getStatus() != OdontogramStatus.BORRADOR) {
            throw new BusinessConflictException("El odontograma ya fue aprobado");
        }
        if (!item.getVersion().equals(version)) {
            throw new BusinessConflictException("El odontograma fue modificado por otro usuario");
        }
    }

    private void validateTooth(DentitionType type, String tooth) {
        if (!(type == DentitionType.PERMANENTE ? PERMANENT : PRIMARY).contains(tooth)) {
            throw new BusinessConflictException("La pieza no corresponde a la dentición seleccionada");
        }
    }

    private void record(AuthenticatedUser actor, String action, Long id, String detail,
                        HttpServletRequest request) {
        audit.record(patients.actorEntity(actor), action, "ODONTOGRAMA", id.toString(),
                AuditResult.EXITO, detail, request);
    }

    private String trim(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
