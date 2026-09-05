package pe.com.dentalamericana;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class DentalAmericanaApplication {
    public static void main(String[] args) {
        SpringApplication.run(DentalAmericanaApplication.class, args);
    }
}
