package pe.com.dentalamericana.odontogram.dto;
import pe.com.dentalamericana.odontogram.*;
import java.time.Instant;
public record OdontogramFindingResponse(Long id,String tooth,ToothSurface surface,ToothCondition condition,TreatmentState treatmentState,String observation,Instant createdAt,Instant updatedAt,Long version){
 public static OdontogramFindingResponse from(OdontogramFinding f){return new OdontogramFindingResponse(f.getId(),f.getTooth(),f.getSurface(),f.getCondition(),f.getTreatmentState(),f.getObservation(),f.getCreatedAt(),f.getUpdatedAt(),f.getVersion());}
}
