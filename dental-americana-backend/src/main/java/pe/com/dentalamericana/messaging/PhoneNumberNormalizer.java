package pe.com.dentalamericana.messaging;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.LinkedHashSet;
import java.util.List;

@Component
public class PhoneNumberNormalizer {
    private final String defaultCountryCode;

    public PhoneNumberNormalizer(@Value("${app.whatsapp.default-country-code:51}") String defaultCountryCode) {
        String digits = digits(defaultCountryCode);
        if (digits.isBlank() || digits.length() > 3) throw new IllegalStateException("Código de país de WhatsApp inválido");
        this.defaultCountryCode = digits;
    }

    public String outbound(String value) {
        String normalized = digits(value);
        if (normalized.startsWith("00")) normalized = normalized.substring(2);
        if (normalized.startsWith("0") && normalized.length() == 10) normalized = normalized.substring(1);
        if (normalized.length() == 9) normalized = defaultCountryCode + normalized;
        if (normalized.length() < 8 || normalized.length() > 15) {
            throw new IllegalArgumentException("El celular no tiene un formato válido para WhatsApp");
        }
        return normalized;
    }

    public List<String> lookupCandidates(String value) {
        String full = outbound(value);
        LinkedHashSet<String> candidates = new LinkedHashSet<>();
        candidates.add(full);
        if (full.startsWith(defaultCountryCode) && full.length() > defaultCountryCode.length()) {
            candidates.add(full.substring(defaultCountryCode.length()));
        }
        return List.copyOf(candidates);
    }

    private static String digits(String value) {
        return value == null ? "" : value.replaceAll("\\D", "");
    }
}
