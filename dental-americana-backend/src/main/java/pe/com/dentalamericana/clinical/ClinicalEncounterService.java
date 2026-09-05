package pe.com.dentalamericana.clinical;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.appointment.Appointment;
import pe.com.dentalamericana.appointment.AppointmentRepository;
import pe.com.dentalamericana.appointment.AppointmentStatus;
import pe.com.dentalamericana.appointment.AppointmentStatusHistory;
import pe.com.dentalamericana.appointment.AppointmentStatusHistoryRepository;
import pe.com.dentalamericana.clinical.dto.*;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.common.BusinessConflictException;
import pe.com.dentalamericana.common.ResourceNotFoundException;
import pe.com.dentalamericana.patient.Patient;
import pe.com.dentalamericana.patient.PatientService;
import pe.com.dentalamericana.odontogram.OdontogramRepository;
import pe.com.dentalamericana.odontogram.OdontogramStatus;
import pe.com.dentalamericana.messaging.FollowUpService;
import pe.com.dentalamericana.messaging.MessageOutboxService;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.user.AppUser;
import pe.com.dentalamericana.user.AppUserRepository;
import pe.com.dentalamericana.user.RoleCode;

import java.time.*;
import java.util.List;

@Service
public class ClinicalEncounterService {
    private final ClinicalEncounterRepository encounters;
    private final ClinicalEncounterVersionRepository versions;
    private final AppointmentRepository appointments;
    private final AppointmentStatusHistoryRepository appointmentHistory;
    private final PatientService patients;
    private final AppUserRepository users;
    private final AuditService audit;
    private final ObjectMapper objectMapper;
    private final OdontogramRepository odontograms;
    private final FollowUpService followUps;
    private final MessageOutboxService messageOutbox;

    public ClinicalEncounterService(ClinicalEncounterRepository encounters, ClinicalEncounterVersionRepository versions,
                                    AppointmentRepository appointments, AppointmentStatusHistoryRepository appointmentHistory,
                                    PatientService patients, AppUserRepository users,
                                    AuditService audit, ObjectMapper objectMapper, OdontogramRepository odontograms,
                                    FollowUpService followUps, MessageOutboxService messageOutbox) {
        this.encounters = encounters; this.versions = versions; this.appointments = appointments;
        this.appointmentHistory = appointmentHistory;
        this.patients = patients; this.users = users; this.audit = audit; this.objectMapper = objectMapper;
        this.odontograms = odontograms;
        this.followUps = followUps;
        this.messageOutbox = messageOutbox;
    }

    @Transactional(readOnly = true)
    public List<ClinicalEncounterResponse> search(Instant from, Instant to, ClinicalStatus status, Long patientId) {
        if (patientId != null) return encounters.findAllByPatientIdOrderByEncounterDateDesc(patientId).stream().map(this::response).toList();
        if (from == null || to == null || !to.isAfter(from) || Duration.between(from, to).toDays() > 92) {
            throw new BusinessConflictException("Rango de atenciones inválido");
        }
        return encounters.search(from, to, status).stream().map(this::response).toList();
    }

    @Transactional(readOnly = true)
    public ClinicalEncounterResponse get(Long id) { return response(find(id)); }

    @Transactional
    public ClinicalEncounterResponse start(StartEncounterRequest request, AuthenticatedUser actor,
                                           HttpServletRequest httpRequest) {
        AppUser dentist = requireDentist(actor);
        Patient patient = patients.find(request.patientId());
        if (!patient.isActive()) throw new BusinessConflictException("El paciente está inactivo");
        if (request.appointmentId() != null) {
            Appointment appointment = appointments.findById(request.appointmentId())
                    .orElseThrow(() -> new ResourceNotFoundException("Cita no encontrada"));
            if (!appointment.getPatientId().equals(patient.getId())) throw new BusinessConflictException("La cita no pertenece al paciente");
            if (!appointment.getProfessionalId().equals(dentist.getId())) {
                throw new BusinessConflictException("La cita está asignada a otro odontólogo");
            }
            var existing = encounters.findByAppointmentId(request.appointmentId());
            if (existing.isPresent()) {
                synchronizeAppointment(appointment, existing.get().getStatus(), actor.getId());
                return response(existing.get());
            }
            markAppointmentInAttention(appointment, actor.getId());
        }
        ClinicalEncounter saved = encounters.saveAndFlush(new ClinicalEncounter(patient.getId(), request.appointmentId(), dentist.getId(), actor.getId()));
        saveSnapshot(saved, "CREACION", "Atención iniciada", actor.getId());
        record(actor, "INICIAR_ATENCION", saved.getId(), "Paciente " + patient.getHistoryNumber(), httpRequest);
        return response(saved);
    }

    @Transactional
    public ClinicalEncounterResponse update(Long id, ClinicalEncounterRequest request, AuthenticatedUser actor,
                                            HttpServletRequest httpRequest) {
        ClinicalEncounter encounter = find(id); requireDraftAndVersion(encounter, request.version());
        AppUser dentist = requireDentist(actor);
        if (!encounter.getDentistId().equals(dentist.getId())) {
            throw new BusinessConflictException("Solo el odontólogo responsable puede modificar esta atención");
        }
        encounter.update(trim(request.consultationReason()), trim(request.illnessDuration()), trim(request.signsSymptoms()),
                trim(request.chronologicalStory()), request.systolicPressure(), request.diastolicPressure(), request.pulse(),
                request.temperature(), request.respiratoryRate(), request.weightKg(), request.heightCm(),
                trim(request.generalExam()), trim(request.dentalExam()), trim(request.diagnosis()), trim(request.workPlan()),
                trim(request.prognosis()), trim(request.evolution()), trim(request.instructions()), request.nextControlDate(),
                request.discharged(), trim(request.dischargeObservation()), request.patientConsent(), actor.getId());
        encounters.flush(); saveSnapshot(encounter, "ACTUALIZACION", "Borrador clínico actualizado", actor.getId());
        record(actor, "ACTUALIZAR_ATENCION", id, "Borrador clínico", httpRequest);
        return response(encounter);
    }

    @Transactional
    public ClinicalEncounterResponse finalizeEncounter(Long id, FinalizeEncounterRequest request,
                                                       AuthenticatedUser actor, HttpServletRequest httpRequest) {
        ClinicalEncounter encounter = find(id); requireDraftAndVersion(encounter, request.version());
        AppUser dentist = requireDentist(actor);
        if (!encounter.getDentistId().equals(dentist.getId())) throw new BusinessConflictException("Solo el odontólogo responsable puede finalizar esta atención");
        validateRequiredClinicalFields(encounter);
        if (odontograms.findAllByEncounterIdOrderByDentitionType(id).stream().anyMatch(item -> item.getStatus() != OdontogramStatus.APROBADO)) {
            throw new BusinessConflictException("Apruebe los odontogramas registrados antes de finalizar la atención");
        }
        encounter.finalizeBy(actor.getId()); encounters.flush();
        completeLinkedAppointment(encounter, actor.getId());
        saveSnapshot(encounter, "FINALIZACION", "Registro clínico aprobado por el odontólogo", actor.getId());
        followUps.schedule(encounter.getPatientId(), encounter.getId(), actor.getId());
        record(actor, "FINALIZAR_ATENCION", id, "Aprobación profesional", httpRequest);
        return response(encounter);
    }

    private ClinicalEncounterResponse response(ClinicalEncounter encounter) {
        Patient patient = patients.find(encounter.getPatientId());
        AppUser dentist = users.findById(encounter.getDentistId()).orElseThrow(() -> new ResourceNotFoundException("Odontólogo no encontrado"));
        String name = String.join(" ", patient.getFirstNames(), patient.getPaternalSurname(),
                patient.getMaternalSurname() == null ? "" : patient.getMaternalSurname()).trim();
        int age = Period.between(patient.getBirthDate(), LocalDate.now()).getYears();
        return new ClinicalEncounterResponse(encounter.getId(), patient.getId(), patient.getHistoryNumber(), name, age,
                encounter.getAppointmentId(), dentist.getId(), dentist.getFullName(), encounter.getEncounterDate(),
                encounter.getStatus(), encounter.getConsultationReason(), encounter.getIllnessDuration(), encounter.getSignsSymptoms(),
                encounter.getChronologicalStory(), encounter.getSystolicPressure(), encounter.getDiastolicPressure(),
                encounter.getPulse(), encounter.getTemperature(), encounter.getRespiratoryRate(), encounter.getWeightKg(),
                encounter.getHeightCm(), encounter.getGeneralExam(), encounter.getDentalExam(), encounter.getDiagnosis(),
                encounter.getWorkPlan(), encounter.getPrognosis(), encounter.getEvolution(), encounter.getInstructions(),
                encounter.getNextControlDate(), encounter.isDischarged(), encounter.getDischargeObservation(),
                encounter.isPatientConsent(), encounter.getApprovedBy(), encounter.getApprovedAt(), encounter.getCreatedAt(),
                encounter.getUpdatedAt(), encounter.getVersion());
    }

    private void saveSnapshot(ClinicalEncounter encounter, String action, String summary, Long actorId) {
        try {
            String data = objectMapper.writeValueAsString(response(encounter));
            versions.save(new ClinicalEncounterVersion(encounter.getId(), encounter.getVersion(), action, summary, data, actorId));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("No se pudo generar la versión de la atención");
        }
    }
    private void validateRequiredClinicalFields(ClinicalEncounter encounter) {
        if (isBlank(encounter.getConsultationReason()) || isBlank(encounter.getDentalExam()) ||
                isBlank(encounter.getDiagnosis()) || isBlank(encounter.getWorkPlan())) {
            throw new BusinessConflictException("Complete motivo, examen odontológico, diagnóstico y plan de trabajo");
        }
        if (!encounter.isPatientConsent()) throw new BusinessConflictException("Debe registrar la conformidad del paciente antes de finalizar");
    }

    private void synchronizeAppointment(Appointment appointment, ClinicalStatus clinicalStatus, Long actorId) {
        if (clinicalStatus == ClinicalStatus.FINALIZADA) {
            markAppointmentCompleted(appointment, actorId);
        } else if (clinicalStatus == ClinicalStatus.BORRADOR) {
            markAppointmentInAttention(appointment, actorId);
        }
    }

    private void markAppointmentInAttention(Appointment appointment, Long actorId) {
        if (appointment.getStatus() == AppointmentStatus.EN_ATENCION) return;
        if (appointment.getStatus().finalState()) {
            throw new BusinessConflictException("No se puede iniciar una atención desde una cita finalizada, cancelada o marcada como inasistencia");
        }
        changeAppointmentStatus(appointment, AppointmentStatus.EN_ATENCION,
                "Atención clínica iniciada", actorId);
        messageOutbox.cancelPendingAppointmentMessages(appointment.getId());
    }

    private void completeLinkedAppointment(ClinicalEncounter encounter, Long actorId) {
        if (encounter.getAppointmentId() == null) return;
        Appointment appointment = appointments.findById(encounter.getAppointmentId())
                .orElseThrow(() -> new ResourceNotFoundException("Cita vinculada no encontrada"));
        markAppointmentCompleted(appointment, actorId);
    }

    private void markAppointmentCompleted(Appointment appointment, Long actorId) {
        if (appointment.getStatus() == AppointmentStatus.COMPLETADA) return;
        if (appointment.getStatus() == AppointmentStatus.CANCELADA || appointment.getStatus() == AppointmentStatus.NO_ASISTIO) {
            throw new BusinessConflictException("La cita vinculada fue cancelada o marcada como inasistencia");
        }
        changeAppointmentStatus(appointment, AppointmentStatus.COMPLETADA,
                "Atención clínica finalizada y aprobada", actorId);
        messageOutbox.cancelPendingAppointmentMessages(appointment.getId());
    }

    private void changeAppointmentStatus(Appointment appointment, AppointmentStatus newStatus,
                                         String reason, Long actorId) {
        AppointmentStatus previous = appointment.getStatus();
        appointment.changeStatus(newStatus, null, actorId);
        appointmentHistory.save(new AppointmentStatusHistory(
                appointment.getId(), previous, newStatus, reason, actorId));
    }
    private AppUser requireDentist(AuthenticatedUser actor) {
        AppUser user = users.findById(actor.getId()).orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));
        if (!user.isActive() || user.isLocked() || user.getRoles().stream().noneMatch(role -> role.getCode() == RoleCode.ODONTOLOGO)) {
            throw new BusinessConflictException("La acción requiere un odontólogo activo");
        }
        return user;
    }
    private ClinicalEncounter find(Long id) { return encounters.findById(id).orElseThrow(() -> new ResourceNotFoundException("Atención no encontrada")); }
    private void requireDraftAndVersion(ClinicalEncounter encounter, Long version) { if (encounter.getStatus() != ClinicalStatus.BORRADOR) throw new BusinessConflictException("La atención ya no se encuentra en borrador"); if (!encounter.getVersion().equals(version)) throw new BusinessConflictException("La atención fue modificada por otro usuario"); }
    private void record(AuthenticatedUser actor, String action, Long id, String detail, HttpServletRequest request) { audit.record(patients.actorEntity(actor), action, "ATENCION_CLINICA", id.toString(), AuditResult.EXITO, detail, request); }
    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }
    private boolean isBlank(String value) { return value == null || value.isBlank(); }
}
