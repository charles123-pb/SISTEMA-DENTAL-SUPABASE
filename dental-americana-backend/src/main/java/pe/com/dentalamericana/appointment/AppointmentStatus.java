package pe.com.dentalamericana.appointment;

public enum AppointmentStatus {
    PENDIENTE_CONFIRMACION,
    CONFIRMADA,
    EN_ESPERA,
    EN_ATENCION,
    COMPLETADA,
    CANCELADA,
    NO_ASISTIO;

    public boolean blocksAgenda() { return this != CANCELADA && this != NO_ASISTIO; }
    public boolean finalState() { return this == COMPLETADA || this == CANCELADA || this == NO_ASISTIO; }
}
