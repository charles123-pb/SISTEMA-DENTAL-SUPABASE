package pe.com.dentalamericana.messaging;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import pe.com.dentalamericana.messaging.dto.MessagingDtos.*;
import pe.com.dentalamericana.security.AuthenticatedUser;

import java.nio.charset.StandardCharsets;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class MessagingController {
    private final MessagingService service;
    private final MetaWebhookProcessor webhook;
    private final String verifyToken;

    public MessagingController(MessagingService service, MetaWebhookProcessor webhook,
                               @Value("${app.whatsapp.webhook-verify-token}") String verifyToken) {
        this.service = service;
        this.webhook = webhook;
        this.verifyToken = verifyToken;
    }

    @GetMapping("/messaging/messages")
    @PreAuthorize("hasAuthority('SEGUIMIENTO_LEER')")
    public List<MessageResponse> messages() { return service.messages(); }

    @GetMapping("/messaging/follow-ups")
    @PreAuthorize("hasAuthority('SEGUIMIENTO_LEER')")
    public List<FollowUpResponse> followups() { return service.followups(); }

    @PostMapping("/messaging/messages")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('SEGUIMIENTO_ESCRIBIR')")
    public MessageResponse manual(@Valid @RequestBody ManualMessageRequest request,
                                  @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest http) {
        return service.manual(request, actor, http);
    }

    @PatchMapping("/messaging/follow-ups/{id}/review")
    @PreAuthorize("hasAuthority('SEGUIMIENTO_ESCRIBIR')")
    public FollowUpResponse review(@PathVariable Long id, @Valid @RequestBody ReviewRequest request,
                                   @AuthenticationPrincipal AuthenticatedUser actor, HttpServletRequest http) {
        return service.review(id, request, actor, http);
    }

    @GetMapping(value = "/whatsapp/webhook", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> verifyWebhook(@RequestParam(name = "hub.mode") String mode,
                                                @RequestParam(name = "hub.verify_token") String token,
                                                @RequestParam(name = "hub.challenge") String challenge) {
        if (!"subscribe".equals(mode) || !constantEquals(verifyToken, token)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Verificación de webhook inválida");
        }
        return ResponseEntity.ok(challenge);
    }

    @PostMapping(value = "/whatsapp/webhook", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Void> webhook(@RequestHeader(value = "X-Hub-Signature-256", required = false) String signature,
                                        @RequestBody byte[] payload) {
        if (!webhook.hasAppSecret()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Webhook no configurado");
        if (!webhook.validSignature(payload, signature)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Firma de webhook inválida");
        }
        try {
            webhook.process(payload);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException exception) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, exception.getMessage());
        }
    }

    private boolean constantEquals(String expected, String supplied) {
        if (expected == null || expected.isBlank() || supplied == null) return false;
        return java.security.MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                supplied.getBytes(StandardCharsets.UTF_8));
    }
}
