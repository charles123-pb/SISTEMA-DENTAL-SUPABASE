package pe.com.dentalamericana.patient;

import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class PatientSpecification {
    private PatientSpecification() {}

    public static Specification<Patient> filter(String query, Boolean active, Sex sex,
                                                Integer minAge, Integer maxAge,
                                                LocalDate registeredFrom, LocalDate registeredTo) {
        return (root, criteriaQuery, cb) -> {
            List<jakarta.persistence.criteria.Predicate> predicates = new ArrayList<>();
            if (query != null && !query.isBlank()) {
                String like = "%" + query.trim().toLowerCase(Locale.ROOT) + "%";
                var fullName = cb.lower(cb.concat(cb.concat(cb.concat(root.<String>get("firstNames"), " "),
                        root.<String>get("paternalSurname")), cb.concat(" ", cb.coalesce(root.<String>get("maternalSurname"), ""))));
                predicates.add(cb.or(
                        cb.like(cb.lower(root.<String>get("historyNumber")), like),
                        cb.like(cb.lower(cb.coalesce(root.<String>get("documentNumber"), "")), like),
                        cb.like(fullName, like),
                        cb.like(cb.coalesce(root.<String>get("celular"), ""), like),
                        cb.like(cb.lower(cb.coalesce(root.<String>get("email"), "")), like)
                ));
            }
            if (active != null) predicates.add(cb.equal(root.get("active"), active));
            if (sex != null) predicates.add(cb.equal(root.get("sex"), sex));
            LocalDate today = LocalDate.now();
            if (minAge != null) predicates.add(cb.lessThanOrEqualTo(root.get("birthDate"), today.minusYears(minAge)));
            if (maxAge != null) predicates.add(cb.greaterThan(root.get("birthDate"), today.minusYears(maxAge + 1L)));
            if (registeredFrom != null) predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), registeredFrom.atStartOfDay().toInstant(java.time.ZoneOffset.UTC)));
            if (registeredTo != null) predicates.add(cb.lessThan(root.get("createdAt"), registeredTo.plusDays(1).atStartOfDay().toInstant(java.time.ZoneOffset.UTC)));
            return cb.and(predicates.toArray(jakarta.persistence.criteria.Predicate[]::new));
        };
    }
}
