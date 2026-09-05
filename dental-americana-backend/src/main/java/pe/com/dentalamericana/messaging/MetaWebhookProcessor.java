package pe.com.dentalamericana.messaging;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;

@Service
public class MetaWebhookProcessor {
    private final MetaWebhookEventHandler messaging;
    private final ObjectMapper mapper;
    private final String appSecret;

    public MetaWebhookProcessor(MetaWebhookEventHandler messaging, ObjectMapper mapper,
                                @Value("${app.whatsapp.app-secret:}") String appSecret) {
        this.messaging = messaging;
        this.mapper = mapper;
        this.appSecret = appSecret;
    }

    public boolean hasAppSecret() { return appSecret != null && !appSecret.isBlank(); }

    public boolean validSignature(byte[] payload, String header) {
        if (!hasAppSecret() || header == null || !header.startsWith("sha256=")) return false;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(appSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] expected = mac.doFinal(payload);
            byte[] provided = HexFormat.of().parseHex(header.substring("sha256=".length()));
            return MessageDigest.isEqual(expected, provided);
        } catch (Exception exception) {
            return false;
        }
    }

    public void process(byte[] payload) {
        try {
            JsonNode root = mapper.readTree(payload);
            if (!"whatsapp_business_account".equals(root.path("object").asText())) return;
            for (JsonNode entry : root.path("entry")) {
                for (JsonNode change : entry.path("changes")) {
                    JsonNode value = change.path("value");
                    processStatuses(value.path("statuses"));
                    processMessages(value.path("messages"));
                }
            }
        } catch (Exception exception) {
            throw new IllegalArgumentException("Payload de Meta WhatsApp inválido", exception);
        }
    }

    private void processStatuses(JsonNode statuses) {
        for (JsonNode status : statuses) {
            MessageStatus mapped = switch (status.path("status").asText()) {
                case "sent" -> MessageStatus.ENVIADO;
                case "delivered" -> MessageStatus.ENTREGADO;
                case "read" -> MessageStatus.LEIDO;
                case "failed" -> MessageStatus.FALLIDO;
                default -> null;
            };
            if (mapped != null) messaging.providerStatus(status.path("id").asText(null), mapped, error(status));
        }
    }

    private void processMessages(JsonNode messages) {
        for (JsonNode message : messages) {
            String phone = message.path("from").asText(null);
            String providerId = message.path("id").asText(null);
            if (phone == null || providerId == null) continue;
            String contextId = message.path("context").path("id").asText(null);
            messaging.handleIncoming(phone, content(message), providerId, contextId);
        }
    }

    private String content(JsonNode message) {
        String type = message.path("type").asText("unknown");
        return switch (type) {
            case "text" -> message.path("text").path("body").asText("[Mensaje vacío]");
            case "button" -> firstText(message.path("button"), "text", "payload");
            case "interactive" -> interactiveContent(message.path("interactive"));
            default -> "[Mensaje de WhatsApp tipo " + type + " requiere revisión manual]";
        };
    }

    private String interactiveContent(JsonNode interactive) {
        JsonNode reply = interactive.has("button_reply") ? interactive.path("button_reply") : interactive.path("list_reply");
        return firstText(reply, "title", "id");
    }

    private String firstText(JsonNode node, String first, String second) {
        String value = node.path(first).asText(null);
        if (value == null || value.isBlank()) value = node.path(second).asText("[Respuesta interactiva]");
        return value;
    }

    private String error(JsonNode status) {
        JsonNode first = status.path("errors").path(0);
        if (first.isMissingNode()) return null;
        String code = first.path("code").asText("");
        String title = first.path("title").asText(first.path("message").asText("Error reportado por Meta"));
        return code.isBlank() ? title : "Meta " + code + ": " + title;
    }
}
