package pe.com.dentalamericana.appointment;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.messaging.MessageOutboxService;
import pe.com.dentalamericana.messaging.MessageType;
import pe.com.dentalamericana.patient.Patient;
import pe.com.dentalamericana.patient.PatientService;

import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
public class AppointmentReminderScheduler {
    private static final long REMINDER_HOURS = 24;
    private static final List<AppointmentStatus> ELIGIBLE = List.of(
            AppointmentStatus.PENDIENTE_CONFIRMACION, AppointmentStatus.CONFIRMADA);

    private final AppointmentRepository appointments;
    private final PatientService patients;
    private final MessageOutboxService outbox;
    private final ZoneId clinicZone;

    public AppointmentReminderScheduler(AppointmentRepository appointments, PatientService patients,
                                        MessageOutboxService outbox,
                                        @Value("${app.clinic.zone-id}") String zoneId) {
        this.appointments = appointments;
        this.patients = patients;
        this.outbox = outbox;
        this.clinicZone = ZoneId.of(zoneId);
    }

    @Scheduled(fixedDelayString = "${app.whatsapp.reminder-scan-delay-ms:300000}")
    @Transactional
    public void queueMissingReminders() {
        Instant now = Instant.now();
        Instant limit = now.plus(REMINDER_HOURS, ChronoUnit.HOURS);
        for (Appointment appointment : appointments
                .findTop50ByReminderScheduledFalseAndInicioBetweenAndEstadoInOrderByInicioAsc(now, limit, ELIGIBLE)) {
            Instant reminderThreshold = appointment.getStart().minus(REMINDER_HOURS, ChronoUnit.HOURS);
            if (appointment.getCreatedAt().isAfter(reminderThreshold)) continue;
            Patient patient = patients.find(appointment.getPatientId());
            var queued = outbox.queueAppointmentReminder(patient, appointment.getId(), appointment.getStart(),
                    now, clinicZone, appointment.getUpdatedBy());
            if (queued != null || outbox.hasActiveAppointmentMessage(appointment.getId(), MessageType.CITA_RECORDATORIO)) {
                appointment.markReminderQueued(appointment.getUpdatedBy());
            }
        }
    }
}
