package pe.com.dentalamericana.appointment;

import jakarta.persistence.*;

@Entity
@Table(name = "tipos_cita")
public class AppointmentType {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(nullable = false, unique = true, length = 40) private String codigo;
    @Column(nullable = false, length = 100) private String nombre;
    @Column(name = "duracion_minutos", nullable = false) private int durationMinutes;
    @Column(nullable = false, length = 10) private String color;
    @Column(nullable = false) private boolean activo = true;

    protected AppointmentType() {}
    public Long getId() { return id; }
    public String getCode() { return codigo; }
    public String getName() { return nombre; }
    public int getDurationMinutes() { return durationMinutes; }
    public String getColor() { return color; }
    public boolean isActive() { return activo; }
}
