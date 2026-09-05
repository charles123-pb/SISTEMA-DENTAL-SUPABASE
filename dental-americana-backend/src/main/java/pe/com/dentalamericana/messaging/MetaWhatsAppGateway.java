package pe.com.dentalamericana.messaging;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import java.util.List;
import java.util.Map;

@Component
@ConditionalOnProperty(name = "app.whatsapp.enabled", havingValue = "true")
public class MetaWhatsAppGateway implements WhatsAppGateway {
    private final RestClient client;
    private final ObjectMapper mapper;
    private final String phoneId;
    private final String languageCode;

    public MetaWhatsAppGateway(RestClient.Builder builder, ObjectMapper mapper,
                               @Value("${app.whatsapp.graph-base-url}") String base,
                               @Value("${app.whatsapp.phone-number-id}") String phoneId,
                               @Value("${app.whatsapp.access-token}") String token,
                               @Value("${app.whatsapp.template-language:es_PE}") String languageCode) {
        if (phoneId == null || phoneId.isBlank()) throw new IllegalStateException("Falta WHATSAPP_PHONE_NUMBER_ID");
        if (token == null || token.isBlank()) throw new IllegalStateException("Falta WHATSAPP_ACCESS_TOKEN");
        this.client = builder.baseUrl(base).defaultHeader("Authorization", "Bearer " + token).build();
        this.mapper = mapper;
        this.phoneId = phoneId.trim();
        this.languageCode = languageCode.trim();
    }

    @Override
    public GatewayResult send(String phone, WhatsAppMessage message) {
        try {
            Map<String, Object> body = requestBody(phone, message);
            @SuppressWarnings("unchecked")
            Map<String, Object> result = client.post()
                    .uri("/{phoneId}/messages", phoneId)
                    .body(body)
                    .retrieve()
                    .body(Map.class);
            String providerId = extractProviderId(result);
            if (providerId == null) return GatewayResult.failed("Meta no devolvió el identificador del mensaje", true);
            return GatewayResult.sent(providerId);
        } catch (RestClientResponseException exception) {
            int status = exception.getStatusCode().value();
            boolean retryable = status == 408 || status == 429 || status >= 500;
            return GatewayResult.failed("Meta WhatsApp HTTP " + status + ": " + safeResponse(exception), retryable);
        } catch (RestClientException exception) {
            return GatewayResult.failed("No se pudo conectar con Meta WhatsApp: " + exception.getMessage(), true);
        } catch (Exception exception) {
            return GatewayResult.failed("Configuración de mensaje inválida: " + exception.getMessage(), false);
        }
    }

    private Map<String, Object> requestBody(String phone, WhatsAppMessage message) throws Exception {
        if (message.getTemplateName() == null) {
            if (message.getType() != MessageType.MANUAL) {
                throw new IllegalStateException("Falta configurar la plantilla Meta para " + message.getType());
            }
            return Map.of(
                    "messaging_product", "whatsapp",
                    "recipient_type", "individual",
                    "to", phone,
                    "type", "text",
                    "text", Map.of("preview_url", false, "body", message.getContent())
            );
        }
        List<String> values = mapper.readValue(message.getTemplateParameters(), new TypeReference<>() {});
        List<Map<String, Object>> parameters = values.stream()
                .map(value -> Map.<String, Object>of("type", "text", "text", value))
                .toList();
        return Map.of(
                "messaging_product", "whatsapp",
                "recipient_type", "individual",
                "to", phone,
                "type", "template",
                "template", Map.of(
                        "name", message.getTemplateName(),
                        "language", Map.of("code", languageCode),
                        "components", List.of(Map.of("type", "body", "parameters", parameters))
                )
        );
    }

    private String extractProviderId(Map<String, Object> result) {
        if (result == null || !(result.get("messages") instanceof List<?> list) || list.isEmpty()) return null;
        if (!(list.get(0) instanceof Map<?, ?> first)) return null;
        Object id = first.get("id");
        return id == null ? null : id.toString();
    }

    private String safeResponse(RestClientResponseException exception) {
        String body = exception.getResponseBodyAsString();
        if (body == null || body.isBlank()) return exception.getStatusText();
        String clean = body.replaceAll("[\\r\\n]+", " ").trim();
        return clean.length() <= 350 ? clean : clean.substring(0, 350);
    }
}
