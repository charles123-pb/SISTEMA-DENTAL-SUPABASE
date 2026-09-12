package pe.com.dentalamericana.appointment;

import org.junit.jupiter.api.Test;
import pe.com.dentalamericana.appointment.dto.AppointmentStatusRequest;
import pe.com.dentalamericana.clinical.ClinicalEncounter;
import pe.com.dentalamericana.clinical.ClinicalEncounterRepository;
import pe.com.dentalamericana.clinical.ClinicalStatus;
import pe.com.dentalamericana.common.BusinessConflictException;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.user.AppUser;
import java.util.Optional;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class AppointmentServiceTest {
    private final AppointmentRepository appointments = mock(AppointmentRepository.class);
    private final ClinicalEncounterRepository encounters = mock(ClinicalEncounterRepository.class);

    @Test
    void cannotCompleteAppointmentWithDraftClinicalRecord() {
        Appointment appointment = appointment();
        ClinicalEncounter encounter = mock(ClinicalEncounter.class);
        when(encounter.getStatus()).thenReturn(ClinicalStatus.BORRADOR);
        when(encounters.findByAppointmentId(1L)).thenReturn(Optional.of(encounter));
        assertThrows(BusinessConflictException.class, () -> service().changeStatus(1L,
                new AppointmentStatusRequest(AppointmentStatus.COMPLETADA, null, 0L), actor(), null));
        verify(appointment, never()).changeStatus(any(), any(), any());
    }

    @Test
    void cannotCompleteAppointmentWithoutClinicalRecord() {
        Appointment appointment = appointment();
        assertThrows(BusinessConflictException.class, () -> service().changeStatus(1L,
                new AppointmentStatusRequest(AppointmentStatus.COMPLETADA, null, 0L), actor(), null));
        verify(appointment, never()).changeStatus(any(), any(), any());
    }

    @Test
    void cannotCancelAppointmentWithExistingClinicalRecord() {
        Appointment appointment = appointment();
        when(encounters.findByAppointmentId(1L)).thenReturn(Optional.of(mock(ClinicalEncounter.class)));
        assertThrows(BusinessConflictException.class, () -> service().changeStatus(1L,
                new AppointmentStatusRequest(AppointmentStatus.CANCELADA, "Prueba", 0L), actor(), null));
        verify(appointment, never()).changeStatus(any(), any(), any());
    }

    private Appointment appointment() {
        Appointment appointment = mock(Appointment.class);
        when(appointment.getVersion()).thenReturn(0L);
        when(appointment.getStatus()).thenReturn(AppointmentStatus.EN_ATENCION);
        when(appointments.findById(1L)).thenReturn(Optional.of(appointment));
        return appointment;
    }

    private AuthenticatedUser actor() {
        return AuthenticatedUser.from(new AppUser("doctor", "hash", "Doctor de prueba"));
    }

    private AppointmentService service() {
        return new AppointmentService(appointments, null, null, null, null, null, null, null,
                "America/Lima", null, encounters);
    }
}
