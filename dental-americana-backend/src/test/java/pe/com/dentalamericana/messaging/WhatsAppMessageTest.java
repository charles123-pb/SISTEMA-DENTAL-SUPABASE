package pe.com.dentalamericana.messaging;

import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

class WhatsAppMessageTest {
    @Test
    void retriesWithoutExceedingConfiguredMaximum() {
        WhatsAppMessage message = WhatsAppMessage.outgoing(1L, 2L, 3L, null,
                MessageType.CITA_RECORDATORIO, "Recordatorio", Instant.now(),
                "dental_cita_recordatorio", "[]", 3, 4L);

        message.registerAttempt();
        message.retry("Temporal", Instant.now().plusSeconds(60));

        assertThat(message.getStatus()).isEqualTo(MessageStatus.PENDIENTE);
        assertThat(message.getAttempts()).isEqualTo(1);
        assertThat(message.canRetry()).isTrue();
        assertThat(message.getErrorDetail()).isEqualTo("Temporal");
    }

    @Test
    void providerStatusDoesNotDowngradeReadMessage() {
        WhatsAppMessage message = WhatsAppMessage.outgoing(1L, 2L, null, null,
                MessageType.MANUAL, "Hola", Instant.now(), null, "[]", 1, 4L);
        message.registerAttempt();
        message.sent("wamid.1");
        message.providerStatus(MessageStatus.LEIDO, null);
        message.providerStatus(MessageStatus.ENTREGADO, null);

        assertThat(message.getStatus()).isEqualTo(MessageStatus.LEIDO);
    }
}
