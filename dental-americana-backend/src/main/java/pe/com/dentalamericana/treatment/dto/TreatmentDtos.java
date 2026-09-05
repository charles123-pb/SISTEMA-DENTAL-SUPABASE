package pe.com.dentalamericana.treatment.dto;
import jakarta.validation.constraints.*;import pe.com.dentalamericana.treatment.*;import java.math.BigDecimal;import java.time.*;import java.util.List;
public final class TreatmentDtos{private TreatmentDtos(){}
 public record ServiceResponse(Long id,String code,String name,String category,String description,BigDecimal basePrice,int suggestedSessions){public static ServiceResponse from(ServiceCatalog s){return new ServiceResponse(s.getId(),s.getCode(),s.getName(),s.getCategory(),s.getDescription(),s.getBasePrice(),s.getSuggestedSessions());}}
 public record CreatePlanRequest(@NotNull Long patientId,Long encounterId,@Size(max=1000)String observations){}
 public record AddItemRequest(@NotNull Long serviceId,@Size(max=3)String tooth,@Size(max=500)String description,@Min(1)@Max(99)int quantity,@NotNull @DecimalMin("0.00")BigDecimal unitPrice,@Min(1)@Max(50)int sessions){}
 public record ChangePlanStatusRequest(@NotNull TreatmentPlanStatus status,boolean patientAcceptance,@NotNull Long version){}
 public record RevisePlanRequest(@NotNull @DecimalMin("0.00")BigDecimal discount,@Size(max=1000)String observations,@NotNull Long version){}
 public record ChangeItemStatusRequest(@NotNull TreatmentItemStatus status,@NotNull Long version){}
 public record EvolutionRequest(Long encounterId,@NotBlank String procedure,String observations,@FutureOrPresent LocalDate nextSession,@AssertTrue boolean professionalConfirmation){}
 public record EvolutionResponse(Long id,Long itemId,Long encounterId,Instant date,String procedure,String observations,LocalDate nextSession,Long approvedBy){public static EvolutionResponse from(TreatmentEvolution e){return new EvolutionResponse(e.getId(),e.getItemId(),e.getEncounterId(),e.getDate(),e.getProcedure(),e.getObservations(),e.getNextSession(),e.getApprovedBy());}}
 public record ItemResponse(Long id,Long serviceId,String serviceName,String tooth,String description,int quantity,BigDecimal unitPrice,BigDecimal subtotal,int sessions,TreatmentItemStatus status,Long version,List<EvolutionResponse>evolutions){}
 public record PlanResponse(Long id,Long patientId,String patientName,Long encounterId,String code,TreatmentPlanStatus status,BigDecimal discount,BigDecimal subtotal,BigDecimal total,String observations,boolean patientAccepted,Instant acceptedAt,Instant createdAt,Instant updatedAt,Long version,List<ItemResponse>items){}
}
