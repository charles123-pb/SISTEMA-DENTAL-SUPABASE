package pe.com.dentalamericana.copilot;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.audit.*;
import pe.com.dentalamericana.clinical.*;
import pe.com.dentalamericana.common.*;
import pe.com.dentalamericana.copilot.dto.CopilotDtos.*;
import pe.com.dentalamericana.patient.*;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.user.*;
import java.time.Period;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class CopilotService {
    private static final String WARNING="Contenido preparado como borrador. No constituye diagnóstico ni reemplaza el criterio del odontólogo.";
    private final AiDraftRepository drafts; private final ClinicalEncounterRepository encounters; private final PatientRepository patients;
    private final PatientHistoryRepository histories; private final PatientAllergyRepository allergies; private final PatientMedicationRepository medications;
    private final AppUserRepository users; private final AuditService audit; private final ObjectMapper mapper;
    public CopilotService(AiDraftRepository drafts,ClinicalEncounterRepository encounters,PatientRepository patients,PatientHistoryRepository histories,PatientAllergyRepository allergies,PatientMedicationRepository medications,AppUserRepository users,AuditService audit,ObjectMapper mapper){this.drafts=drafts;this.encounters=encounters;this.patients=patients;this.histories=histories;this.allergies=allergies;this.medications=medications;this.users=users;this.audit=audit;this.mapper=mapper;}

    @Transactional(readOnly=true) public List<DraftResponse> list(Long encounterId){requireEncounter(encounterId);return drafts.findAllByEncounterIdOrderByGeneratedAtDesc(encounterId).stream().map(this::response).toList();}

    @Transactional public DraftResponse generate(GenerateDraftRequest request,AuthenticatedUser actor,HttpServletRequest http){ClinicalEncounter e=requireEncounter(request.encounterId());Patient p=requirePatient(e.getPatientId());List<String>missing=missing(e);String content=switch(request.type()){case RESUMEN_HISTORIA->historySummary(p,e);case BORRADOR_EVOLUCION->evolutionDraft(e);case INDICACIONES_POSTCONSULTA->instructionsDraft(e);case VERIFICACION_CIERRE->verification(e,missing);case PLAN_TRATAMIENTO->treatmentPlanDraft(e);case ALERTAS_CLINICAS->clinicalAlerts(p,e);case RESUMEN_PARA_PACIENTE->patientSummary(p,e);};try{Map<String,Object>source=new LinkedHashMap<>();source.put("atencionId",e.getId());source.put("atencionVersion",e.getVersion());source.put("pacienteId",p.getId());source.put("numeroHistoria",p.getHistoryNumber());source.put("tipo",request.type());source.put("generadoDesde","DATOS_ESTRUCTURADOS_DEL_SISTEMA");AiDraft d=drafts.save(new AiDraft(e.getId(),p.getId(),request.type(),content,mapper.writeValueAsString(source),mapper.writeValueAsString(missing),WARNING,actor.getId()));record(actor,"GENERAR_BORRADOR_IA",d.getId(),request.type().name(),http);return response(d);}catch(JsonProcessingException ex){throw new IllegalStateException("No se pudo preparar la trazabilidad del borrador");}}

    @Transactional public DraftResponse approve(Long id,ReviewDraftRequest request,AuthenticatedUser actor,HttpServletRequest http){requireDentist(actor);AiDraft d=find(id);checkVersion(d,request.version());checkSource(d);try{d.approve(actor.getId());}catch(IllegalStateException ex){throw new BusinessConflictException(ex.getMessage());}drafts.flush();record(actor,"APROBAR_BORRADOR_IA",id,d.getType().name(),http);return response(d);}

    @Transactional public DraftResponse edit(Long id, EditDraftRequest request, AuthenticatedUser actor, HttpServletRequest http) {
        requireDentist(actor);
        AiDraft draft = find(id);
        checkVersion(draft, request.version());
        checkSource(draft);
        try { draft.edit(request.content()); } catch (IllegalStateException ex) { throw new BusinessConflictException(ex.getMessage()); }
        drafts.flush();
        record(actor, "EDITAR_BORRADOR_IA", id, draft.getType().name(), http);
        return response(draft);
    }

    private void checkSource(AiDraft draft) {
        try {
            var source = mapper.readTree(draft.getSourceData());
            Long currentVersion = requireEncounter(draft.getEncounterId()).getVersion();
            if (!source.has("atencionVersion") || source.path("atencionVersion").asLong(-1) != currentVersion) {
                throw new BusinessConflictException("La atención cambió desde que se generó el borrador. Genere uno nuevo y revíselo.");
            }
        } catch (JsonProcessingException ex) { throw new BusinessConflictException("No se pudo verificar la fuente del borrador"); }
    }
    @Transactional public DraftResponse reject(Long id,ReviewDraftRequest request,AuthenticatedUser actor,HttpServletRequest http){requireDentist(actor);if(request.reason()==null||request.reason().isBlank())throw new BusinessConflictException("Indique el motivo del rechazo");AiDraft d=find(id);checkVersion(d,request.version());try{d.reject(actor.getId(),request.reason().trim());}catch(IllegalStateException ex){throw new BusinessConflictException(ex.getMessage());}record(actor,"RECHAZAR_BORRADOR_IA",id,request.reason(),http);return response(d);}

    private String historySummary(Patient p,ClinicalEncounter e){String name=fullName(p);String history=histories.findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(p.getId()).stream().map(h->h.getType()+": "+h.getDescription()).collect(Collectors.joining("; "));String allergy=allergies.findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(p.getId()).stream().map(a->a.getSubstance()+(a.getReaction()==null?"":" ("+a.getReaction()+")")).collect(Collectors.joining(", "));String meds=medications.findAllByPatientIdAndActivoTrueOrderByVigenteDescCreatedAtDesc(p.getId()).stream().filter(PatientMedication::isCurrent).map(PatientMedication::getMedication).collect(Collectors.joining(", "));return "Resumen previo de "+name+" (HC "+p.getHistoryNumber()+", "+Period.between(p.getBirthDate(),java.time.LocalDate.now()).getYears()+" años).\n\nAntecedentes registrados: "+empty(history)+".\nAlergias registradas: "+empty(allergy)+".\nMedicación vigente: "+empty(meds)+".\nMotivo de la atención: "+empty(e.getConsultationReason())+".";}
    private String evolutionDraft(ClinicalEncounter e){return "Borrador de evolución\n\nMotivo referido: "+empty(e.getConsultationReason())+".\nHallazgos del examen odontológico: "+empty(e.getDentalExam())+".\nDiagnóstico registrado por el odontólogo: "+empty(e.getDiagnosis())+".\nPlan de trabajo registrado: "+empty(e.getWorkPlan())+".\nEvolución consignada: "+empty(e.getEvolution())+".\n\nRevisar precisión clínica antes de aprobar.";}
    private String instructionsDraft(ClinicalEncounter e){return "Borrador de indicaciones postconsulta\n\nIndicaciones registradas en la atención: "+empty(e.getInstructions())+".\nPróximo control: "+(e.getNextControlDate()==null?"no registrado":e.getNextControlDate())+".\n\nEl odontólogo debe completar, corregir y aprobar las indicaciones antes de enviarlas al paciente.";}
    private String treatmentPlanDraft(ClinicalEncounter e){return "Borrador de plan de tratamiento\n\nDiagnóstico registrado: "+empty(e.getDiagnosis())+".\nPlan clínico registrado: "+empty(e.getWorkPlan())+".\nPronóstico: "+empty(e.getPrognosis())+".\n\nRevise procedimientos, piezas, secuencia, presupuesto y consentimiento antes de presentarlo al paciente.";}
    private String clinicalAlerts(Patient p,ClinicalEncounter e){String allergy=allergies.findAllByPatientIdAndActivoTrueOrderByCreatedAtDesc(p.getId()).stream().map(a->a.getSubstance()+(a.getReaction()==null?"":" ("+a.getReaction()+")")).collect(Collectors.joining(", "));String meds=medications.findAllByPatientIdAndActivoTrueOrderByVigenteDescCreatedAtDesc(p.getId()).stream().filter(PatientMedication::isCurrent).map(PatientMedication::getMedication).collect(Collectors.joining(", "));return "Revisión de alertas clínicas\n\nAlergias registradas: "+empty(allergy)+".\nMedicación vigente: "+empty(meds)+".\nSignos y síntomas consignados: "+empty(e.getSignsSymptoms())+".\n\nVerifique estos datos con el paciente antes de decidir cualquier procedimiento, anestésico o prescripción.";}
    private String patientSummary(Patient p,ClinicalEncounter e){return "Borrador de resumen para "+fullName(p)+"\n\nEn esta visita se registró: "+empty(e.getDentalExam())+".\nEl odontólogo consignó el siguiente plan: "+empty(e.getWorkPlan())+".\nIndicaciones: "+empty(e.getInstructions())+".\nPróximo control: "+(e.getNextControlDate()==null?"por coordinar":e.getNextControlDate())+".\n\nUse lenguaje claro, confirme que el contenido es correcto y apruébelo antes de compartirlo.";}
    private String verification(ClinicalEncounter e,List<String>missing){return missing.isEmpty()?"Verificación completada: los campos mínimos para finalizar están registrados. El odontólogo aún debe revisar su coherencia y aprobar la atención.":"La atención todavía tiene campos pendientes: "+String.join(", ",missing)+". No debe finalizarse hasta que el profesional los complete y revise.";}
    private List<String>missing(ClinicalEncounter e){List<String>m=new ArrayList<>();if(blank(e.getConsultationReason()))m.add("motivo de consulta");if(blank(e.getSignsSymptoms()))m.add("signos y síntomas");if(blank(e.getDentalExam()))m.add("examen odontológico");if(blank(e.getDiagnosis()))m.add("diagnóstico profesional");if(blank(e.getWorkPlan()))m.add("plan de trabajo");if(blank(e.getEvolution()))m.add("evolución");if(blank(e.getInstructions()))m.add("indicaciones");if(!e.isPatientConsent())m.add("conformidad del paciente");return m;}
    private DraftResponse response(AiDraft d){try{return new DraftResponse(d.getId(),d.getEncounterId(),d.getPatientId(),d.getType(),d.getStatus(),d.getContent(),mapper.readValue(d.getMissingFields(),new TypeReference<List<String>>(){}),d.getWarning(),d.getRejectionReason(),d.getGeneratedBy(),d.getGeneratedAt(),d.getReviewedBy(),d.getReviewedAt(),d.getVersion());}catch(JsonProcessingException ex){throw new IllegalStateException("Borrador con datos inválidos");}}
    private ClinicalEncounter requireEncounter(Long id){return encounters.findById(id).orElseThrow(()->new ResourceNotFoundException("Atención no encontrada"));}
    private Patient requirePatient(Long id){return patients.findById(id).orElseThrow(()->new ResourceNotFoundException("Paciente no encontrado"));}
    private AiDraft find(Long id){return drafts.findById(id).orElseThrow(()->new ResourceNotFoundException("Borrador no encontrado"));}
    private void checkVersion(AiDraft d,Long version){if(!d.getVersion().equals(version))throw new BusinessConflictException("El borrador fue actualizado por otro usuario");}
    private void requireDentist(AuthenticatedUser actor){AppUser u=users.findById(actor.getId()).orElseThrow(()->new ResourceNotFoundException("Usuario no encontrado"));if(!u.isActive()||u.isLocked()||u.getRoles().stream().noneMatch(r->r.getCode()==RoleCode.ODONTOLOGO))throw new BusinessConflictException("La revisión requiere un odontólogo activo");}
    private void record(AuthenticatedUser actor,String action,Long id,String detail,HttpServletRequest http){AppUser u=users.findById(actor.getId()).orElse(null);audit.record(u,action,"BORRADOR_IA",id.toString(),AuditResult.EXITO,detail,http);}
    private String fullName(Patient p){return String.join(" ",p.getFirstNames(),p.getPaternalSurname(),p.getMaternalSurname()==null?"":p.getMaternalSurname()).trim();}
    private String empty(String v){return blank(v)?"sin información registrada":v.trim();} private boolean blank(String v){return v==null||v.isBlank();}
}
