package pe.com.dentalamericana.messaging.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import pe.com.dentalamericana.messaging.*;

import java.time.Instant;

public final class MessagingDtos {
    private MessagingDtos() {}

    public record ManualMessageRequest(@NotNull Long patientId, @NotBlank String content, Instant scheduledFor) {}

    public record MessageResponse(Long id, Long conversationId, Long patientId, String patientName,
                                  Long appointmentId, Long encounterId, MessageDirection direction,
                                  MessageType type, String content, MessageStatus status, Instant scheduledFor,
                                  String intent, boolean reviewRequired, String errorDetail,
                                  int attempts, int maxAttempts, Instant lastAttemptAt,
                                  Instant createdAt, Instant sentAt) {
        public static MessageResponse of(WhatsAppMessage message, String name) {
            return new MessageResponse(message.getId(), message.getConversationId(), message.getPatientId(), name,
                    message.getAppointmentId(), message.getEncounterId(), message.getDirection(), message.getType(),
                    message.getContent(), message.getStatus(), message.getScheduledFor(), message.getIntent(),
                    message.isReviewRequired(), message.getErrorDetail(), message.getAttempts(),
                    message.getMaxAttempts(), message.getLastAttemptAt(), message.getCreatedAt(), message.getSentAt());
        }
    }

    public record FollowUpResponse(Long id, Long patientId, String patientName, Long encounterId, Long messageId,
                                   Instant scheduledFor, FollowUpStatus status, String response,
                                   String classification, String alertReason, Long reviewedBy,
                                   Instant reviewedAt, Long version) {}

    public record ReviewRequest(@NotNull Long version, @AssertTrue boolean professionalReview) {}
}
