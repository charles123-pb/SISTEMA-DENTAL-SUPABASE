package pe.com.dentalamericana.messaging;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name = "app.whatsapp.enabled", havingValue = "false", matchIfMissing = true)
public class DisabledWhatsAppGateway implements WhatsAppGateway {
    @Override
    public GatewayResult send(String phone, WhatsAppMessage message) {
        return GatewayResult.failed("WhatsApp no está habilitado en el servidor", false);
    }
}
