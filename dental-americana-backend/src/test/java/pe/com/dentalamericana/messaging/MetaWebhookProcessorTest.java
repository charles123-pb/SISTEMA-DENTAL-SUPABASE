package pe.com.dentalamericana.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;

import static org.assertj.core.api.Assertions.assertThat;

class MetaWebhookProcessorTest {
    private static final String SECRET = "meta-app-secret-for-tests";
    private final CapturingHandler handler = new CapturingHandler();
    private final MetaWebhookProcessor processor = new MetaWebhookProcessor(handler, new ObjectMapper(), SECRET);

    @Test
    void validatesMetaSha256Signature() throws Exception {
        byte[] payload = "{\"object\":\"whatsapp_business_account\"}".getBytes(StandardCharsets.UTF_8);
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(SECRET.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        String signature = "sha256=" + HexFormat.of().formatHex(mac.doFinal(payload));

        assertThat(processor.validSignature(payload, signature)).isTrue();
        assertThat(processor.validSignature(payload, "sha256=00")).isFalse();
    }

    @Test
    void processesIncomingTextAndDeliveryStatus() {
        String payload = """
                {
                  "object":"whatsapp_business_account",
                  "entry":[{"changes":[{"value":{
                    "statuses":[{"id":"out-1","status":"delivered"}],
                    "messages":[{"from":"51940577075","id":"in-1","type":"text",
                      "context":{"id":"out-1"},"text":{"body":"CONFIRMO"}}]
                  }}]}]
                }
                """;

        processor.process(payload.getBytes(StandardCharsets.UTF_8));

        assertThat(handler.statusProviderId).isEqualTo("out-1");
        assertThat(handler.status).isEqualTo(MessageStatus.ENTREGADO);
        assertThat(handler.incomingPhone).isEqualTo("51940577075");
        assertThat(handler.incomingContent).isEqualTo("CONFIRMO");
        assertThat(handler.incomingProviderId).isEqualTo("in-1");
        assertThat(handler.contextProviderId).isEqualTo("out-1");
    }

    private static final class CapturingHandler implements MetaWebhookEventHandler {
        String incomingPhone;
        String incomingContent;
        String incomingProviderId;
        String contextProviderId;
        String statusProviderId;
        MessageStatus status;

        @Override
        public void handleIncoming(String phone, String content, String providerId, String contextProviderId) {
            this.incomingPhone = phone;
            this.incomingContent = content;
            this.incomingProviderId = providerId;
            this.contextProviderId = contextProviderId;
        }

        @Override
        public void providerStatus(String providerId, MessageStatus status, String error) {
            this.statusProviderId = providerId;
            this.status = status;
        }
    }
}
