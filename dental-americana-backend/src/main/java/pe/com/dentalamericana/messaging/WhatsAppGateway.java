package pe.com.dentalamericana.messaging;

public interface WhatsAppGateway {
    GatewayResult send(String phone, WhatsAppMessage message);

    record GatewayResult(boolean sent, String providerId, String error, boolean retryable) {
        public static GatewayResult sent(String providerId) { return new GatewayResult(true, providerId, null, false); }
        public static GatewayResult failed(String error, boolean retryable) { return new GatewayResult(false, null, error, retryable); }
    }
}
