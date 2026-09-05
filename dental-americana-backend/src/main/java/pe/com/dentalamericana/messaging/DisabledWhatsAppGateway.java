package pe.com.dentalamericana.messaging;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnMissingBean(WhatsAppGateway.class)
public class DisabledWhatsAppGateway implements WhatsAppGateway {
    @Override
    public GatewayResult send(String phone, WhatsAppMessage message) {
        return GatewayResult.failed("WhatsApp no está habilitado en el servidor", false);
    }
}
