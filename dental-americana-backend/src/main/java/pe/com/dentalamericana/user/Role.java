package pe.com.dentalamericana.user;

import jakarta.persistence.*;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "roles")
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "codigo", nullable = false, unique = true, length = 40)
    private RoleCode code;

    @Column(name = "nombre", nullable = false, length = 80)
    private String name;

    @Column(name = "descripcion", length = 250)
    private String description;

    @Column(name = "activo", nullable = false)
    private boolean active = true;

    @ManyToMany(fetch = FetchType.EAGER)
    @JoinTable(name = "roles_permisos",
            joinColumns = @JoinColumn(name = "rol_id"),
            inverseJoinColumns = @JoinColumn(name = "permiso_id"))
    private Set<Permission> permissions = new LinkedHashSet<>();

    protected Role() {}

    public Long getId() { return id; }
    public RoleCode getCode() { return code; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public boolean isActive() { return active; }
    public Set<Permission> getPermissions() { return Set.copyOf(permissions); }
}
