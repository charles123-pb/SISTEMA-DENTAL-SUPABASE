package pe.com.dentalamericana.messaging;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface WhatsAppMessageRepository extends JpaRepository<WhatsAppMessage, Long> {
    List<WhatsAppMessage> findTop50ByOrderByCreatedAtDesc();
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    List<WhatsAppMessage> findTop25ByEstadoAndScheduledForLessThanEqualOrderByScheduledForAsc(MessageStatus status, Instant due);
    List<WhatsAppMessage> findAllByConversationIdOrderByCreatedAtAsc(Long conversationId);
    List<WhatsAppMessage> findAllByAppointmentIdAndEstado(Long appointmentId, MessageStatus status);
    Optional<WhatsAppMessage> findByProviderId(String providerId);
    boolean existsByProviderId(String providerId);
    boolean existsByAppointmentIdAndTipoAndEstadoIn(Long appointmentId, MessageType type, Collection<MessageStatus> statuses);
    long countByEstadoAndCreatedAtBetween(MessageStatus status, Instant from, Instant to);
}
