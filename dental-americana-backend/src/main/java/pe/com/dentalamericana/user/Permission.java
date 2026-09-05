package pe.com.dentalamericana.user;

import jakarta.persistence.*;

@Entity
@Table(name = "permisos")
public class Permission {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "codigo", nullable = false, unique = true, length = 60)
    private PermissionCode code;

    @Column(name = "descripcion", nullable = false, length = 250)
    private String description;

    protected Permission() {}

    public Long getId() { return id; }
    public PermissionCode getCode() { return code; }
    public String getDescription() { return description; }
}
