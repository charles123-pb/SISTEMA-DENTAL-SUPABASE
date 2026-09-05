package pe.com.dentalamericana.audit;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.user.AppUser;

@Service
public class AuditService {
    private final AuditLogRepository repository;

    public AuditService(AuditLogRepository repository) {
        this.repository = repository;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(AppUser user, String action, String resource, String resourceId,
                       AuditResult result, String detail, HttpServletRequest request) {
        String ip = request == null ? null : clientIp(request);
        String userAgent = request == null ? null : truncate(request.getHeader("User-Agent"), 300);
        repository.save(new AuditLog(
                user == null ? null : user.getId(),
                user == null ? null : user.getUsername(),
                action,
                resource,
                resourceId,
                result,
                ip,
                userAgent,
                truncate(detail, 2000)
        ));
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) return truncate(forwarded.split(",")[0].trim(), 64);
        return truncate(request.getRemoteAddr(), 64);
    }

    private String truncate(String value, int max) {
        if (value == null || value.length() <= max) return value;
        return value.substring(0, max);
    }
}
