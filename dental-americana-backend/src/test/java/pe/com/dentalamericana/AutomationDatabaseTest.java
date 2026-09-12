package pe.com.dentalamericana;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import pe.com.dentalamericana.appointment.*;
import pe.com.dentalamericana.patient.*;
import pe.com.dentalamericana.messaging.*;
import pe.com.dentalamericana.clinical.*;
import pe.com.dentalamericana.copilot.*;
import pe.com.dentalamericana.copilot.dto.CopilotDtos.*;
import pe.com.dentalamericana.user.*;
import pe.com.dentalamericana.security.AuthenticatedUser;
import pe.com.dentalamericana.common.BusinessConflictException;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

/** Runs against an isolated PostgreSQL database, never the clinic database. */
@EnabledIfEnvironmentVariable(named="DENTAL_TEST_DB_URL", matches=".+")
@SpringBootTest(properties={"spring.datasource.url=${DENTAL_TEST_DB_URL}",
        "spring.datasource.username=dental_test", "spring.datasource.password=dental_test",
        "app.whatsapp.enabled=false", "app.bootstrap-admin.enabled=false",
        "app.whatsapp.outbox-delay-ms=86400000", "app.whatsapp.reminder-scan-delay-ms=86400000", "debug=false", "logging.level.root=WARN"})
@Transactional
class AutomationDatabaseTest {
    @Autowired JdbcTemplate jdbc;
    @Autowired PatientRepository patients;
    @Autowired AppointmentRepository appointments;
    @Autowired ClinicalEncounterRepository encounters;
    @Autowired MessagingService messaging;
    @Autowired WhatsAppMessageRepository messages;
    @Autowired CopilotService copilot;
    @Autowired AppUserRepository users;
    Patient patient; Long actorId; AuthenticatedUser actor;
    @BeforeAll static void createCommittedActor(@Autowired JdbcTemplate jdbc) {
        jdbc.update("insert into usuarios(username,password_hash,nombre_completo) values ('regression-dentist','unused-test-hash','Odontólogo de pruebas') on conflict (username) do nothing");
        jdbc.update("insert into usuarios_roles(usuario_id,rol_id) select u.id,r.id from usuarios u cross join roles r where u.username='regression-dentist' and r.codigo='ODONTOLOGO' on conflict do nothing");
    }
    @BeforeEach void setup() {
        actorId = jdbc.queryForObject("select id from usuarios where username='regression-dentist'", Long.class);
        actor = AuthenticatedUser.from(users.findById(actorId).orElseThrow());
        patient = new Patient("TEST-"+patients.nextHistorySequence(), actorId);
        patient.updateIdentity(DocumentType.SIN_DOCUMENTO, null, "Prueba", "Automatización", null, LocalDate.of(1990,1,1), Sex.NO_ESPECIFICA);
        patient.updateContact("51999999001", null, null, null);
        patient.updateWhatsAppConsent(true, actorId);
        patients.saveAndFlush(patient);
    }
    Appointment appointment() {
        Long type = jdbc.queryForObject("select min(id) from tipos_cita", Long.class);
        Instant start = Instant.now().plusSeconds(86400);
        return appointments.saveAndFlush(new Appointment(patient.getId(),actorId,type,start,start.plusSeconds(1800),"Prueba aislada",null,AppointmentSource.SISTEMA,actorId));
    }
    @Test void nullableSearchesWorkOnPostgres() {
        var a=appointment();
        assertEquals(1, patients.findDuplicateCandidates(null,"999999001",null,null).size());
        assertEquals(1, patients.findDuplicateCandidates(null,null,patient.getBirthDate(),"Automatización").size());
        assertTrue(appointments.search(Instant.now(),Instant.now().plusSeconds(172800),null,null).stream().anyMatch(x->x.getId().equals(a.getId())));
        assertNotNull(encounters.search(Instant.now().minusSeconds(86400),Instant.now(),null));
    }
    @Test void incomingConfirmationAndCancellationPersistIncludingSystemReplies() {
        var a=appointment();
        messaging.incoming(patient.getMobile(),"CONFIRMO","confirm-test",null);
        messages.flush(); appointments.flush();
        assertEquals(AppointmentStatus.CONFIRMADA, appointments.findById(a.getId()).orElseThrow().getStatus());
        messaging.incoming(patient.getMobile(),"CANCELAR","cancel-test",null);
        messages.flush(); appointments.flush();
        assertEquals(AppointmentStatus.CANCELADA, appointments.findById(a.getId()).orElseThrow().getStatus());
        assertEquals(2, jdbc.queryForObject("select count(*) from mensajes_whatsapp where paciente_id=? and direccion='SALIENTE' and creado_por is null",Integer.class,patient.getId()));
        messaging.incoming(patient.getMobile(),"CANCELAR","cancel-test",null);
        messages.flush();
        assertEquals(1, jdbc.queryForObject("select count(*) from mensajes_whatsapp where proveedor_id='cancel-test'",Integer.class));
    }
    @Test void reservationAndReschedulingAreVisibleAndDoNotDuplicatePendingRequests() {
        appointment();
        messaging.incoming(patient.getMobile(),"REPROGRAMAR","resched1",null);
        messaging.incoming(patient.getMobile(),"REPROGRAMAR","resched2",null);
        messaging.incoming(patient.getMobile(),"RESERVAR","reserve1",null);
        messages.flush();
        assertEquals(2,jdbc.queryForObject("select count(*) from solicitudes_cita_web where celular=?",Integer.class,patient.getMobile()));
    }
    @Test void everyClinicalDraftCanBeGeneratedEditedAndReviewed() {
        var encounter=encounters.saveAndFlush(new ClinicalEncounter(patient.getId(),null,actorId,actorId));
        for(var type:AiDraftType.values()) {
            var generated=copilot.generate(new GenerateDraftRequest(encounter.getId(),type),actor,null);
            var edited=copilot.edit(generated.id(),new EditDraftRequest(generated.version(),"Contenido revisado para prueba aislada"),actor,null);
            var approved=copilot.approve(edited.id(),new ReviewDraftRequest(edited.version(),null),actor,null);
            assertEquals(AiDraftStatus.APROBADO,approved.status());
        }
    }
    @Test void appointmentWithClinicalRecordCannotBeCancelledByWhatsApp() {
        var a = appointment();
        encounters.saveAndFlush(new ClinicalEncounter(patient.getId(), a.getId(), actorId, actorId));
        messaging.incoming(patient.getMobile(), "CANCELAR", "protected-clinical", null);
        messages.flush();
        assertEquals(AppointmentStatus.PENDIENTE_CONFIRMACION, a.getStatus());
    }
    @Test void changedEncounterBlocksStaleDraftApproval() {
        var encounter=encounters.saveAndFlush(new ClinicalEncounter(patient.getId(),null,actorId,actorId));
        var draft=copilot.generate(new GenerateDraftRequest(encounter.getId(),AiDraftType.BORRADOR_EVOLUCION),actor,null);
        org.springframework.test.util.ReflectionTestUtils.setField(encounter,"version",encounter.getVersion()+1);
        assertThrows(BusinessConflictException.class,()->copilot.approve(draft.id(),new ReviewDraftRequest(draft.version(),null),actor,null));
    }
}
