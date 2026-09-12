package pe.com.dentalamericana.copilot;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class AiDraftTest {
    @Test void professionalCanCorrectDraftButNotReviewedContent() {
        var draft = new AiDraft(1L, 1L, AiDraftType.RESUMEN_HISTORIA, "Original", "{}", "[]", "Revisar", 1L);
        draft.edit("Corrección profesional");
        assertEquals("Corrección profesional", draft.getContent());
        draft.approve(1L);
        assertThrows(IllegalStateException.class, () -> draft.edit("Cambio posterior"));
        assertThrows(IllegalStateException.class, () -> draft.reject(1L, "Cambio"));
    }
    @Test void emptyDraftCannotBeSaved() {
        var draft = new AiDraft(1L, 1L, AiDraftType.RESUMEN_HISTORIA, "Original", "{}", "[]", "Revisar", 1L);
        assertThrows(IllegalStateException.class, () -> draft.edit("  "));
    }
}
