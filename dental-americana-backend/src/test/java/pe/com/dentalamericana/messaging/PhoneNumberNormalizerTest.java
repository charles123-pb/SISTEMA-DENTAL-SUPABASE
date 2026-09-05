package pe.com.dentalamericana.messaging;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;

class PhoneNumberNormalizerTest {
    private final PhoneNumberNormalizer normalizer = new PhoneNumberNormalizer("51");

    @Test
    void addsPeruCountryCodeToLocalMobile() {
        assertThat(normalizer.outbound("940 577 075")).isEqualTo("51940577075");
    }

    @Test
    void preservesInternationalNumberAndBuildsLookupCandidates() {
        assertThat(normalizer.outbound("+51 940 577 075")).isEqualTo("51940577075");
        assertThat(normalizer.lookupCandidates("51940577075"))
                .containsExactly("51940577075", "940577075");
    }

    @Test
    void rejectsInvalidPhone() {
        assertThatThrownBy(() -> normalizer.outbound("123"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("formato válido");
    }
}
