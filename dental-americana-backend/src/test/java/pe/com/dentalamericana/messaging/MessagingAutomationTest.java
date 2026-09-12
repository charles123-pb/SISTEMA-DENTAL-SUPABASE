package pe.com.dentalamericana.messaging;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import pe.com.dentalamericana.appointment.*;
import pe.com.dentalamericana.audit.AuditService;
import pe.com.dentalamericana.booking.PublicBookingRequestRepository;
import pe.com.dentalamericana.patient.*;
import java.time.Instant;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class MessagingAutomationTest {
    final WhatsAppMessageRepository messages = mock(WhatsAppMessageRepository.class);
    final WhatsAppConversationRepository conversations = mock(WhatsAppConversationRepository.class);
    final PatientRepository patientRepo = mock(PatientRepository.class);
    final PatientService patients = mock(PatientService.class);
    final AppointmentRepository appointments = mock(AppointmentRepository.class);
    final AppointmentStatusHistoryRepository history = mock(AppointmentStatusHistoryRepository.class);
    final MessageOutboxService outbox = mock(MessageOutboxService.class);
    final PublicBookingRequestRepository bookings = mock(PublicBookingRequestRepository.class);
    final Patient patient = mock(Patient.class);
    MessagingService service;
    @BeforeEach void setup() {
        when(patient.getId()).thenReturn(4L); when(patient.isActive()).thenReturn(true);
        when(patient.getMobile()).thenReturn("51910213190"); when(patient.isWhatsAppConsent()).thenReturn(true);
        when(patient.getFirstNames()).thenReturn("Prueba"); when(patient.getPaternalSurname()).thenReturn("WhatsApp");
        when(patientRepo.findAllByCelularIn(any())).thenReturn(List.of(patient));
        when(patients.find(4L)).thenReturn(patient);
        var conversation = mock(WhatsAppConversation.class); when(conversation.getId()).thenReturn(1L);
        when(conversations.findFirstByTelefonoAndEstadoNot(any(),any())).thenReturn(Optional.of(conversation));
        when(messages.save(any())).thenAnswer(i -> i.getArgument(0));
        service = new MessagingService(messages, conversations, mock(PostConsultationFollowUpRepository.class),
                patientRepo, patients, appointments, history, outbox, new PhoneNumberNormalizer("51"), mock(AuditService.class), bookings);
    }
    Appointment appointment(long id) {
        var a = mock(Appointment.class); when(a.getId()).thenReturn(id); when(a.getPatientId()).thenReturn(4L);
        when(a.getUpdatedBy()).thenReturn(1L); when(a.getStart()).thenReturn(Instant.now().plusSeconds(86400));
        when(a.getStatus()).thenReturn(AppointmentStatus.PENDIENTE_CONFIRMACION); return a;
    }
    @Test void cancellationUpdatesOnlyOneAppointmentAndReplyUsesSystemActor() {
        var a = appointment(8L);
        when(appointments.findAllByPatientIdAndInicioAfterAndEstadoInOrderByInicioAsc(eq(4L),any(),any())).thenReturn(List.of(a));
        service.incoming("910213190", "CANCELAR", "new-1", null);
        verify(a).changeStatus(eq(AppointmentStatus.CANCELADA),anyString(),eq(1L));
        verify(outbox).cancelPendingAppointmentMessages(8L);
        verify(outbox).queueManual(eq(patient),contains("cancelada"),any(),isNull());
    }
    @Test void invalidQuotedMessageNeverFallsBackToAnotherAppointment() {
        service.incoming("910213190", "CANCELAR", "new-2", "invalid-context");
        verifyNoInteractions(appointments, history);
        verify(outbox).queueManual(eq(patient),contains("No cambiamos"),any(),isNull());
    }
    @Test void severalAppointmentsRequireExplicitContext() {
        var a = appointment(8L); var b = appointment(9L);
        when(appointments.findAllByPatientIdAndInicioAfterAndEstadoInOrderByInicioAsc(eq(4L),any(),any())).thenReturn(List.of(a,b));
        service.incoming("910213190", "CONFIRMO", "new-3", null);
        verify(a,never()).changeStatus(any(),any(),any()); verify(b,never()).changeStatus(any(),any(),any());
        verify(outbox).queueManual(eq(patient),contains("varias citas"),any(),isNull());
    }
    @Test void duplicateWebhookDoesNotRepeatActions() {
        when(messages.findByProviderId("duplicate")).thenReturn(Optional.of(WhatsAppMessage.incoming(1L,4L,"duplicate","CANCELAR","CANCELAR",false)));
        service.incoming("910213190", "CANCELAR", "duplicate", null);
        verifyNoInteractions(appointments, outbox, bookings);
    }
    @Test void negationsAndQuestionsDoNotChangeAgenda() {
        for (String text : List.of("No quiero cancelar", "¿Puedo cancelar mi cita?", "No confirmo", "¿Cuándo es mi cita?", "no reservar", "de acuerdo"))
            assertEquals("NO_ENTENDIDO", AppointmentIntentClassifier.classify(text), text);
        assertEquals("CANCELAR", AppointmentIntentClassifier.classify("Por favor cancelar mi cita"));
        assertEquals("REPROGRAMAR", AppointmentIntentClassifier.classify("Quiero reprogramar mi cita"));
        assertEquals("RESERVAR", AppointmentIntentClassifier.classify("Quiero una cita"));
    }
    @Test void inboundDeliveryStatusCannotOverwriteReceivedState() {
        var incoming = WhatsAppMessage.incoming(1L, 4L, "incoming", "hola", "AYUDA", false);
        incoming.providerStatus(MessageStatus.ENTREGADO, null);
        assertEquals(MessageStatus.RECIBIDO, incoming.getStatus());
    }
}
