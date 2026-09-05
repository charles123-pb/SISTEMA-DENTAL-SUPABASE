package pe.com.dentalamericana.audit;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "auditoria")
public class AuditLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "usuario_id")
    private Long userId;

    @Column(length = 60)
    private String username;

    @Column(name = "accion", nullable = false, length = 80)
    private String action;

    @Column(name = "recurso", nullable = false, length = 80)
    private String resource;

    @Column(name = "recurso_id", length = 80)
    private String resourceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "resultado", nullable = false, length = 20)
    private AuditResult result;

    @Column(length = 64)
    private String ip;

    @Column(name = "user_agent", length = 300)
    private String userAgent;

    @Column(name = "detalle", columnDefinition = "TEXT")
    private String detail;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private Instant createdAt;

    protected AuditLog() {}

    public AuditLog(Long userId, String username, String action, String resource,
                    String resourceId, AuditResult result, String ip, String userAgent, String detail) {
        this.userId = userId;
        this.username = username;
        this.action = action;
        this.resource = resource;
        this.resourceId = resourceId;
        this.result = result;
        this.ip = ip;
        this.userAgent = userAgent;
        this.detail = detail;
    }

    @PrePersist
    void onCreate() { createdAt = Instant.now(); }

    public Long getId() { return id; }
    public Long getUserId() { return userId; }
    public String getUsername() { return username; }
    public String getAction() { return action; }
    public String getResource() { return resource; }
    public String getResourceId() { return resourceId; }
    public AuditResult getResult() { return result; }
    public String getIp() { return ip; }
    public String getDetail() { return detail; }
    public Instant getCreatedAt() { return createdAt; }
}
