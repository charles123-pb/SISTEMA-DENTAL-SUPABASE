package pe.com.dentalamericana.user;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "usuarios")
public class AppUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 60)
    private String username;

    @Column(name = "password_hash", nullable = false, length = 100)
    private String passwordHash;

    @Column(name = "nombre_completo", nullable = false, length = 150)
    private String fullName;

    @Column(unique = true, length = 150)
    private String email;

    @Column(name = "activo", nullable = false)
    private boolean active = true;

    @Column(name = "bloqueado", nullable = false)
    private boolean locked;

    @Column(name = "intentos_fallidos", nullable = false)
    private int failedAttempts;

    @Column(name = "ultimo_acceso")
    private Instant lastAccess;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "actualizado_en", nullable = false)
    private Instant updatedAt;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "usuarios_roles",
            joinColumns = @JoinColumn(name = "usuario_id"),
            inverseJoinColumns = @JoinColumn(name = "rol_id"))
    private Set<Role> roles = new LinkedHashSet<>();

    protected AppUser() {}

    public AppUser(String username, String passwordHash, String fullName) {
        this.username = username;
        this.passwordHash = passwordHash;
        this.fullName = fullName;
    }

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() { updatedAt = Instant.now(); }

    public void assignRole(Role role) { roles.add(role); }
    public void replaceRoles(Set<Role> newRoles) { roles.clear(); roles.addAll(newRoles); }
    public void changePassword(String encodedPassword) { this.passwordHash = encodedPassword; }
    public void changeActive(boolean active) { this.active = active; }
    public void changeContact(String fullName, String email) { this.fullName = fullName; this.email = email; }
    public void registerSuccessfulAccess() { lastAccess = Instant.now(); failedAttempts = 0; }
    public void registerFailedAttempt() { failedAttempts++; }

    public Long getId() { return id; }
    public String getUsername() { return username; }
    public String getPasswordHash() { return passwordHash; }
    public String getFullName() { return fullName; }
    public String getEmail() { return email; }
    public boolean isActive() { return active; }
    public boolean isLocked() { return locked; }
    public int getFailedAttempts() { return failedAttempts; }
    public Instant getLastAccess() { return lastAccess; }
    public Set<Role> getRoles() { return Set.copyOf(roles); }
}
