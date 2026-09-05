package pe.com.dentalamericana.audit;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.Instant;

public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {
    @Query("""
        select a from AuditLog a where a.createdAt between :from and :to
        and (lower(coalesce(a.username,'')) like lower(concat('%',:query,'%'))
          or lower(a.action) like lower(concat('%',:query,'%'))
          or lower(a.resource) like lower(concat('%',:query,'%')))
        order by a.createdAt desc
        """)
    Page<AuditLog> search(@Param("from")Instant from,@Param("to")Instant to,@Param("query")String query,Pageable pageable);

    @Query("""
        select a from AuditLog a where a.createdAt between :from and :to
        order by a.createdAt desc
        """)
    Page<AuditLog> searchAll(@Param("from")Instant from,@Param("to")Instant to,Pageable pageable);
}
