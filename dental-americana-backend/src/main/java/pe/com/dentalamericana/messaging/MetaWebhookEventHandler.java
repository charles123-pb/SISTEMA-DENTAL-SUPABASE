package pe.com.dentalamericana.messaging;

public interface MetaWebhookEventHandler {
    void handleIncoming(String phone, String content, String providerId, String contextProviderId);
    void providerStatus(String providerId, MessageStatus status, String error);
}
