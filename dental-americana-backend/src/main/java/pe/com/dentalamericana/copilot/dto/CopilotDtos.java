package pe.com.dentalamericana.copilot.dto;
import jakarta.validation.constraints.*;
import pe.com.dentalamericana.copilot.*;
import java.time.Instant;
import java.util.List;
public final class CopilotDtos{private CopilotDtos(){}
 public record GenerateDraftRequest(@NotNull Long encounterId,@NotNull AiDraftType type){}
 public record ReviewDraftRequest(@NotNull Long version,@Size(max=500)String reason){}
 public record DraftResponse(Long id,Long encounterId,Long patientId,AiDraftType type,AiDraftStatus status,String content,List<String>missingFields,String warning,String rejectionReason,Long generatedBy,Instant generatedAt,Long reviewedBy,Instant reviewedAt,Long version){}
}
