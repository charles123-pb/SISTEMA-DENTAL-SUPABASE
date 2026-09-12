package pe.com.dentalamericana.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import pe.com.dentalamericana.appointment.AppointmentRepository;
import pe.com.dentalamericana.patient.Patient;
import pe.com.dentalamericana.patient.PatientRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class MessageOutboxServiceTest {
    private final WhatsAppMessageRepository messages = mock(WhatsAppMessageRepository.class);
    private final WhatsAppConversationRepository conversations = mock(WhatsAppConversationRepository.class);
    private final PatientRepository patients = mock(PatientRepository.class);
    private final PostConsultationFollowUpRepository followups = mock(PostConsultationFollowUpRepository.class);
    private final WhatsAppGateway gateway = mock(WhatsAppGateway.class);

    @Test
    void revokedConsentCancelsQueuedMessageWithoutContactingProvider() {
        WhatsAppMessage message = pending();
        Patient patient = mock(Patient.class);
        when(patient.isActive()).thenReturn(true);
        when(patient.getMobile()).thenReturn("999111222");
        when(patient.isWhatsAppConsent()).thenReturn(false);
        prepare(message, patient);
        service().dispatch();
        assertEquals(MessageStatus.CANCELADO, message.getStatus());
        assertEquals(0, message.getAttempts());
        verifyNoInteractions(gateway);
    }

    @Test
    void changedPhoneCancelsMessageToOldNumber() {
        WhatsAppMessage message = pending();
        Patient patient = mock(Patient.class);
        when(patient.isActive()).thenReturn(true);
        when(patient.getMobile()).thenReturn("999333444");
        when(patient.isWhatsAppConsent()).thenReturn(true);
        prepare(message, patient);
        service().dispatch();
        assertEquals(MessageStatus.CANCELADO, message.getStatus());
        verifyNoInteractions(gateway);
    }

    @Test
    void transientProviderFailureSchedulesRetry() {
        WhatsAppMessage message = pending();
        Patient patient = mock(Patient.class);
        when(patient.isActive()).thenReturn(true);
        when(patient.getMobile()).thenReturn("999111222");
        when(patient.isWhatsAppConsent()).thenReturn(true);
        prepare(message, patient);
        when(gateway.send("51999111222", message))
                .thenReturn(WhatsAppGateway.GatewayResult.failed("Servicio temporalmente caído", true));
        service().dispatch();
        assertEquals(MessageStatus.PENDIENTE, message.getStatus());
        assertEquals(1, message.getAttempts());
        assertTrue(message.getScheduledFor().isAfter(Instant.now()));
    }

    private WhatsAppMessage pending() {
        return WhatsAppMessage.outgoing(1L, 2L, null, null, MessageType.MANUAL,
                "Prueba", Instant.now(), null, "[]", 3, 3L);
    }

    private void prepare(WhatsAppMessage message, Patient patient) {
        when(messages.findTop25ByEstadoAndScheduledForLessThanEqualOrderByScheduledForAsc(
                eq(MessageStatus.PENDIENTE), any())).thenReturn(List.of(message));
        when(conversations.findById(1L)).thenReturn(Optional.of(new WhatsAppConversation(2L, "51999111222")));
        when(patients.findById(2L)).thenReturn(Optional.of(patient));
    }

    private MessageOutboxService service() {
        return new MessageOutboxService(conversations, messages, followups,
                mock(AppointmentRepository.class), patients, gateway, new PhoneNumberNormalizer("51"),
                new ObjectMapper(), "confirmation", "reminder", "followup", 3);
    }
}
