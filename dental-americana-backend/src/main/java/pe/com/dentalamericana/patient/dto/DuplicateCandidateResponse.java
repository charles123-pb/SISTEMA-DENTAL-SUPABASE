package pe.com.dentalamericana.patient.dto;

public record DuplicateCandidateResponse(Long id, String historyNumber, String fullName,
                                         String documentNumber, String mobile, String reason) {}
