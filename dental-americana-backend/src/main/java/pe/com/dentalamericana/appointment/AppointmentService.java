package pe.com.dentalamericana.appointment;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.appointment.dto.*;
import pe.com.dentalamericana.audit.AuditResult;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.common.BusinessConflictException;
import pe.com.dentalamericana.common.ResourceNotFoundException;
import pe.com.dentalamericana.patient.Patient;
import pe.com.dentalamericana.messaging.MessageOutboxService;
import pe.com.dentalamericana.patient.PatientService;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.user.AppUser;
import pe.com.dentalamericana.user.AppUserRepository;
import pe.com.dentalamericana.user.RoleCode;

import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
public class AppointmentService {
    private static final Set<AppointmentStatus> TERMINAL = Set.of(
            AppointmentStatus.COMPLETADA, AppointmentStatus.CANCELADA, AppointmentStatus.NO_ASISTIO);
    private final AppointmentRepository appointments;
    private final AppointmentTypeRepository types;
    private final ProfessionalScheduleRepository schedules;
    private final ScheduleBlockRepository blocks;
    private final AppointmentStatusHistoryRepository history;
    private final AppUserRepository users;
    private final PatientService patients;
    private final AuditService audit;
    private final ZoneId clinicZone;
    private final MessageOutboxService outbox;

    public AppointmentService(AppointmentRepository appointments, AppointmentTypeRepository types,
                              ProfessionalScheduleRepository schedules, ScheduleBlockRepository blocks,
                              AppointmentStatusHistoryRepository history, AppUserRepository users,
                              PatientService patients, AuditService audit,
                              @Value("${app.clinic.zone-id}") String zoneId, MessageOutboxService outbox) {
        this.appointments = appointments; this.types = types; this.schedules = schedules; this.blocks = blocks;
        this.history = history; this.users = users; this.patients = patients; this.audit = audit;
        this.clinicZone = ZoneId.of(zoneId);
        this.outbox = outbox;
    }

    @Transactional(readOnly = true)
    public List<AppointmentTypeResponse> listTypes() {
        return types.findAllByActivoTrueOrderByNombreAsc().stream().map(AppointmentTypeResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<ProfessionalResponse> listProfessionals() {
        return users.findActiveDentists().stream().map(ProfessionalResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> search(Instant from, Instant to, Long professionalId, AppointmentStatus status) {
        validateRange(from, to, 62);
        return appointments.search(from, to, professionalId, status).stream().map(this::response).toList();
    }

    @Transactional(readOnly = true)
    public AppointmentResponse get(Long id) { return response(find(id)); }

    @Transactional(readOnly = true)
    public List<AvailabilitySlotResponse> availability(Long professionalId, LocalDate date, Long appointmentTypeId) {
        AppUser professional = findProfessional(professionalId);
        AppointmentType type = findType(appointmentTypeId);
        List<ProfessionalSchedule> configured = schedules
                .findAllByProfessionalIdAndDayOfWeekAndActivoTrueOrderByStartTimeAsc(professional.getId(), date.getDayOfWeek().getValue());
        List<Window> windows = configured.isEmpty() ? defaultWindows(date) : configured.stream()
                .map(item -> new Window(item.getStartTime(), item.getEndTime(), item.getIntervalMinutes())).toList();
        if (windows.isEmpty()) return List.of();

        Instant dayStart = date.atStartOfDay(clinicZone).toInstant();
        Instant dayEnd = date.plusDays(1).atStartOfDay(clinicZone).toInstant();
        List<Appointment> daily = appointments.search(dayStart, dayEnd, professionalId, null);
        List<ScheduleBlock> blocked = blocks.findOverlapping(professionalId, dayStart, dayEnd);
        List<AvailabilitySlotResponse> result = new ArrayList<>();
        Instant now = Instant.now();
        for (Window window : windows) {
            ZonedDateTime cursor = date.atTime(window.start()).atZone(clinicZone);
            ZonedDateTime windowEnd = date.atTime(window.end()).atZone(clinicZone);
            while (!cursor.plusMinutes(type.getDurationMinutes()).isAfter(windowEnd)) {
                Instant start = cursor.toInstant(); Instant end = cursor.plusMinutes(type.getDurationMinutes()).toInstant();
                String reason = unavailableReason(start, end, now, daily, blocked);
                result.add(new AvailabilitySlotResponse(start, end, reason == null, reason));
                cursor = cursor.plusMinutes(window.intervalMinutes());
            }
        }
        return result;
    }

    @Transactional
    public AppointmentResponse create(AppointmentRequest request, AuthenticatedUser actor, HttpServletRequest httpRequest) {
        Patient patient = patients.find(request.patientId());
        if (!patient.isActive()) throw new BusinessConflictException("No se puede citar a un paciente inactivo");
        AppointmentType type = findType(request.appointmentTypeId());
        AppUser professional = findProfessional(request.professionalId());
        Instant end = request.start().plus(type.getDurationMinutes(), ChronoUnit.MINUTES);
        validateAvailability(patient.getId(), professional.getId(), request.start(), end, 0L);
        Appointment saved = appointments.saveAndFlush(new Appointment(patient.getId(), professional.getId(), type.getId(),
                request.start(), end, request.reason().trim(), trim(request.notes()),
                request.source() == null ? AppointmentSource.RECEPCION : request.source(), actor.getId()));
        history.save(new AppointmentStatusHistory(saved.getId(), null, saved.getStatus(), "Cita creada", actor.getId()));
        outbox.queueAppointmentConfirmation(patient, saved.getId(), saved.getStart(), clinicZone, actor.getId());
        scheduleReminder(saved, patient, actor.getId());
        record(actor, "CREAR_CITA", saved.getId(), "Inicio " + saved.getStart(), httpRequest);
        return response(saved);
    }

    @Transactional
    public AppointmentResponse update(Long id, AppointmentRequest request, AuthenticatedUser actor,
                                      HttpServletRequest httpRequest) {
        Appointment appointment = find(id);
        if (appointment.getStatus().finalState()) throw new BusinessConflictException("No se puede reprogramar una cita finalizada");
        requireVersion(appointment, request.version());
        if (!appointment.getPatientId().equals(request.patientId())) throw new BusinessConflictException("No se puede cambiar el paciente de una cita");
        AppointmentType type = findType(request.appointmentTypeId());
        AppUser professional = findProfessional(request.professionalId());
        Instant end = request.start().plus(type.getDurationMinutes(), ChronoUnit.MINUTES);
        validateAvailability(appointment.getPatientId(), professional.getId(), request.start(), end, appointment.getId());
        appointment.reschedule(professional.getId(), type.getId(), request.start(), end, request.reason().trim(),
                trim(request.notes()), actor.getId());
        Patient patient = patients.find(appointment.getPatientId());
        outbox.cancelPendingAppointmentMessages(appointment.getId());
        outbox.queueAppointmentConfirmation(patient, appointment.getId(), appointment.getStart(), clinicZone, actor.getId());
        scheduleReminder(appointment, patient, actor.getId());
        record(actor, "REPROGRAMAR_CITA", appointment.getId(), "Nuevo inicio " + request.start(), httpRequest);
        return response(appointment);
    }

    @Transactional
    public AppointmentResponse changeStatus(Long id, AppointmentStatusRequest request, AuthenticatedUser actor,
                                            HttpServletRequest httpRequest) {
        Appointment appointment = find(id);
        requireVersion(appointment, request.version());
        AppointmentStatus previous = appointment.getStatus();
        if (previous == request.status()) return response(appointment);
        validateTransition(previous, request.status(), request.reason());
        String reason = trim(request.reason());
        appointment.changeStatus(request.status(), request.status() == AppointmentStatus.CANCELADA ? reason : null, actor.getId());
        if (request.status().finalState()) outbox.cancelPendingAppointmentMessages(appointment.getId());
        history.save(new AppointmentStatusHistory(id, previous, request.status(), reason, actor.getId()));
        record(actor, "CAMBIAR_ESTADO_CITA", id, previous + " -> " + request.status(), httpRequest);
        return response(appointment);
    }

    private AppointmentResponse response(Appointment appointment) {
        Patient patient = patients.find(appointment.getPatientId());
        AppUser professional = users.findById(appointment.getProfessionalId())
                .orElseThrow(() -> new ResourceNotFoundException("Profesional no encontrado"));
        AppointmentType type = findType(appointment.getAppointmentTypeId());
        String patientName = String.join(" ", patient.getFirstNames(), patient.getPaternalSurname(),
                patient.getMaternalSurname() == null ? "" : patient.getMaternalSurname()).trim();
        return new AppointmentResponse(appointment.getId(), patient.getId(), patient.getHistoryNumber(), patientName,
                patient.getMobile(), professional.getId(), professional.getFullName(), type.getId(), type.getName(),
                type.getColor(), type.getDurationMinutes(), appointment.getStart(), appointment.getEnd(),
                appointment.getStatus(), appointment.getReason(), appointment.getNotes(), appointment.getSource(),
                appointment.getCancellationReason(), appointment.isConfirmationSent(), appointment.isReminderScheduled(),
                appointment.isReminderSent(),
                appointment.getCreatedAt(), appointment.getUpdatedAt(), appointment.getVersion());
    }

    private void scheduleReminder(Appointment appointment, Patient patient, Long actorId) {
        Instant reminderAt = appointment.getStart().minus(24, ChronoUnit.HOURS);
        if (!reminderAt.isAfter(Instant.now())) return;
        if (outbox.queueAppointmentReminder(patient, appointment.getId(), appointment.getStart(),
                reminderAt, clinicZone, actorId) != null) {
            appointment.markReminderQueued(actorId);
        }
    }

    private void validateAvailability(Long patientId, Long professionalId, Instant start, Instant end, Long excludedId) {
        if (!start.isAfter(Instant.now())) throw new BusinessConflictException("La cita debe programarse en una fecha futura");
        ensureWithinWorkingHours(professionalId, start, end);
        if (!blocks.findOverlapping(professionalId, start, end).isEmpty()) throw new BusinessConflictException("El profesional tiene el horario bloqueado");
        if (appointments.countProfessionalConflicts(professionalId, start, end, excludedId) > 0) throw new BusinessConflictException("El profesional ya tiene una cita en ese horario");
        if (appointments.countPatientConflicts(patientId, start, end, excludedId) > 0) throw new BusinessConflictException("El paciente ya tiene una cita en ese horario");
    }

    private void ensureWithinWorkingHours(Long professionalId, Instant start, Instant end) {
        ZonedDateTime localStart = start.atZone(clinicZone); ZonedDateTime localEnd = end.atZone(clinicZone);
        if (!localStart.toLocalDate().equals(localEnd.toLocalDate())) throw new BusinessConflictException("La cita debe iniciar y terminar el mismo día");
        List<ProfessionalSchedule> configured = schedules.findAllByProfessionalIdAndDayOfWeekAndActivoTrueOrderByStartTimeAsc(
                professionalId, localStart.getDayOfWeek().getValue());
        boolean inside = configured.isEmpty()
                ? defaultWindows(localStart.toLocalDate()).stream().anyMatch(window -> inside(localStart, localEnd, window))
                : configured.stream().anyMatch(item -> inside(localStart, localEnd, new Window(item.getStartTime(), item.getEndTime(), item.getIntervalMinutes())));
        if (!inside) throw new BusinessConflictException("El horario está fuera de la jornada del profesional");
    }

    private boolean inside(ZonedDateTime start, ZonedDateTime end, Window window) {
        return !start.toLocalTime().isBefore(window.start()) && !end.toLocalTime().isAfter(window.end());
    }

    private List<Window> defaultWindows(LocalDate date) {
        return date.getDayOfWeek() == DayOfWeek.SUNDAY ? List.of() : List.of(new Window(LocalTime.of(8, 0), LocalTime.of(20, 0), 15));
    }

    private String unavailableReason(Instant start, Instant end, Instant now, List<Appointment> daily, List<ScheduleBlock> blocked) {
        if (!start.isAfter(now)) return "Horario pasado";
        if (blocked.stream().anyMatch(item -> overlaps(start, end, item.getStart(), item.getEnd()))) return "Horario bloqueado";
        if (daily.stream().anyMatch(item -> item.getStatus().blocksAgenda() && overlaps(start, end, item.getStart(), item.getEnd()))) return "Horario ocupado";
        return null;
    }

    private boolean overlaps(Instant start, Instant end, Instant otherStart, Instant otherEnd) {
        return start.isBefore(otherEnd) && end.isAfter(otherStart);
    }

    private void validateTransition(AppointmentStatus from, AppointmentStatus to, String reason) {
        if (TERMINAL.contains(from)) throw new BusinessConflictException("La cita ya se encuentra finalizada");
        if (to == AppointmentStatus.CANCELADA) {
            if (reason == null || reason.isBlank()) throw new BusinessConflictException("Indique el motivo de cancelación");
            return;
        }
        Map<AppointmentStatus, Set<AppointmentStatus>> allowed = Map.of(
                AppointmentStatus.PENDIENTE_CONFIRMACION, Set.of(AppointmentStatus.CONFIRMADA, AppointmentStatus.NO_ASISTIO),
                AppointmentStatus.CONFIRMADA, Set.of(AppointmentStatus.EN_ESPERA, AppointmentStatus.NO_ASISTIO),
                AppointmentStatus.EN_ESPERA, Set.of(AppointmentStatus.EN_ATENCION, AppointmentStatus.NO_ASISTIO),
                AppointmentStatus.EN_ATENCION, Set.of(AppointmentStatus.COMPLETADA));
        if (!allowed.getOrDefault(from, Set.of()).contains(to)) throw new BusinessConflictException("Cambio de estado no permitido: " + from + " a " + to);
    }

    private AppUser findProfessional(Long id) {
        AppUser user = users.findById(id).orElseThrow(() -> new ResourceNotFoundException("Profesional no encontrado"));
        boolean dentist = user.isActive() && !user.isLocked() && user.getRoles().stream().anyMatch(role -> role.getCode() == RoleCode.ODONTOLOGO);
        if (!dentist) throw new BusinessConflictException("El usuario seleccionado no es un odontólogo activo");
        return user;
    }
    private AppointmentType findType(Long id) { return types.findById(id).filter(AppointmentType::isActive).orElseThrow(() -> new ResourceNotFoundException("Tipo de cita no encontrado")); }
    private Appointment find(Long id) { return appointments.findById(id).orElseThrow(() -> new ResourceNotFoundException("Cita no encontrada")); }
    private void requireVersion(Appointment appointment, Long version) { if (version == null || !appointment.getVersion().equals(version)) throw new BusinessConflictException("La cita fue modificada por otro usuario"); }
    private void validateRange(Instant from, Instant to, int maxDays) { if (from == null || to == null || !to.isAfter(from)) throw new BusinessConflictException("Rango de agenda inválido"); if (Duration.between(from, to).toDays() > maxDays) throw new BusinessConflictException("El rango consultado es demasiado amplio"); }
    private void record(AuthenticatedUser actor, String action, Long id, String detail, HttpServletRequest request) { audit.record(patients.actorEntity(actor), action, "CITA", id.toString(), AuditResult.EXITO, detail, request); }
    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }
    private record Window(LocalTime start, LocalTime end, int intervalMinutes) {}
}
