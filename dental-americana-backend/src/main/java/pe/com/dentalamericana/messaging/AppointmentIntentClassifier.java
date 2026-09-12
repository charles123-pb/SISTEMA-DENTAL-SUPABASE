package pe.com.dentalamericana.messaging;

import java.text.Normalizer;
import java.util.Locale;

/** Explicit commands only: ambiguous prose must never cancel an appointment. */
public final class AppointmentIntentClassifier {
    private AppointmentIntentClassifier() {}
    public static String classify(String text) {
        String value = Normalizer.normalize(text, Normalizer.Form.NFD).replaceAll("\\p{M}", "")
                .toLowerCase(Locale.ROOT).replaceAll("[¿?¡!.,;:]", " ").trim().replaceAll("\\s+", " ");
        if (value.matches("(?:por favor )?(?:confirmo|confirmar|si confirmo)(?: mi cita| la cita)?(?: por favor)?")) return "CONFIRMAR";
        if (value.matches("(?:por favor )?(?:(?:quiero|deseo|necesito) )?(?:cancelar|anular|cancela|anula)(?: mi cita| la cita)?(?: por favor)?")) return "CANCELAR";
        if (value.matches("(?:por favor )?(?:(?:quiero|deseo|necesito) )?(?:reprogramar|posponer|cambiar)(?: mi cita| la cita| el horario)?(?: por favor)?")) return "REPROGRAMAR";
        if (value.matches("(?:(?:quiero|deseo|necesito) )?(?:reservar|agendar|sacar)(?: una cita| cita)?")
                || value.matches("(?:quiero|deseo|necesito) una (?:cita|consulta)")) return "RESERVAR";
        if (value.matches("hola|buenos dias|buenas tardes|buenas noches|menu|ayuda")) return "AYUDA";
        return "NO_ENTENDIDO";
    }
}
