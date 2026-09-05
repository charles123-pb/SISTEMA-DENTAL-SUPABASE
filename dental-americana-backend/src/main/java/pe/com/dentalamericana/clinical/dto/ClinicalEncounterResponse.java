package pe.com.dentalamericana.clinical.dto;

import pe.com.dentalamericana.clinical.ClinicalStatus;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

public record ClinicalEncounterResponse(
        Long id, Long patientId, String patientHistoryNumber, String patientName, int patientAge,
        Long appointmentId, Long dentistId, String dentistName, Instant encounterDate, ClinicalStatus status,
        String consultationReason, String illnessDuration, String signsSymptoms, String chronologicalStory,
        Integer systolicPressure, Integer diastolicPressure, Integer pulse, BigDecimal temperature,
        Integer respiratoryRate, BigDecimal weightKg, BigDecimal heightCm, String generalExam,
        String dentalExam, String diagnosis, String workPlan, String prognosis, String evolution,
        String instructions, LocalDate nextControlDate, boolean discharged, String dischargeObservation,
        boolean patientConsent, Long approvedBy, Instant approvedAt, Instant createdAt, Instant updatedAt, Long version
) {}
