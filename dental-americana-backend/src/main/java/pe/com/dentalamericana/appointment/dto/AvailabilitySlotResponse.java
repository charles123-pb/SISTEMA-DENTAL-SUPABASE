package pe.com.dentalamericana.appointment.dto;

import java.time.Instant;

public record AvailabilitySlotResponse(Instant start, Instant end, boolean available, String unavailableReason) {}
