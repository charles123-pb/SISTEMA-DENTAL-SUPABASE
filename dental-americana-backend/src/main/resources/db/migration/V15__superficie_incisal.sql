-- La superficie incisal corresponde a dientes anteriores; no debe registrarse como oclusal.
ALTER TABLE odontograma_hallazgos DROP CONSTRAINT chk_hallazgo_superficie;
ALTER TABLE odontograma_hallazgos
    ADD CONSTRAINT chk_hallazgo_superficie CHECK (
        superficie IN ('GENERAL','OCLUSAL','INCISAL','MESIAL','DISTAL','VESTIBULAR','LINGUAL_PALATINA')
    );
