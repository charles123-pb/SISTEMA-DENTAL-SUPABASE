package pe.com.dentalamericana.odontogram.dto;
import pe.com.dentalamericana.odontogram.*;
import java.time.Instant;
import java.util.List;
public record OdontogramResponse(Long id,Long encounterId,Long patientId,DentitionType dentitionType,OdontogramStatus status,String generalObservation,Long approvedBy,Instant approvedAt,Instant createdAt,Instant updatedAt,Long version,List<OdontogramFindingResponse> findings){}
