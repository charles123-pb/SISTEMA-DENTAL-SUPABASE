package pe.com.dentalamericana.clinical.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDate;

public record ClinicalEncounterRequest(
        @Size(max = 1000) String consultationReason,
        @Size(max = 250) String illnessDuration,
        @Size(max = 1500) String signsSymptoms,
        String chronologicalStory,
        @Min(40) @Max(300) Integer systolicPressure,
        @Min(20) @Max(200) Integer diastolicPressure,
        @Min(20) @Max(250) Integer pulse,
        @DecimalMin("30.0") @DecimalMax("45.0") BigDecimal temperature,
        @Min(5) @Max(80) Integer respiratoryRate,
        @DecimalMin("0.50") @DecimalMax("500.00") BigDecimal weightKg,
        @DecimalMin("20.00") @DecimalMax("250.00") BigDecimal heightCm,
        String generalExam,
        String dentalExam,
        String diagnosis,
        String workPlan,
        @Size(max = 500) String prognosis,
        String evolution,
        String instructions,
        @FutureOrPresent LocalDate nextControlDate,
        boolean discharged,
        @Size(max = 1000) String dischargeObservation,
        boolean patientConsent,
        @NotNull Long version
) {}
