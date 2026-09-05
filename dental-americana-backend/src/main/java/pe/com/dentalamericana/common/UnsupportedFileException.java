package pe.com.dentalamericana.common;

import org.springframework.http.HttpStatus;

public class UnsupportedFileException extends RuntimeException {
    private final HttpStatus status;

    public UnsupportedFileException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() { return status; }
}
