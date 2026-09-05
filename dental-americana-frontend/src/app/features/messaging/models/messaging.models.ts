export type MessageType =
  'ENTRANTE' | 'CITA_CONFIRMACION' | 'CITA_RECORDATORIO' | 'POSTCONSULTA' | 'MANUAL';
export interface Message {
  id: number;
  conversationId: number;
  patientId?: number;
  patientName: string;
  appointmentId?: number;
  encounterId?: number;
  direction: 'ENTRANTE' | 'SALIENTE';
  type: MessageType;
  content: string;
  status: string;
  scheduledFor?: string;
  intent?: string;
  reviewRequired: boolean;
  errorDetail?: string;
  attempts: number;
  maxAttempts: number;
  lastAttemptAt?: string;
  createdAt: string;
  sentAt?: string;
}
export interface FollowUp {
  id: number;
  patientId: number;
  patientName: string;
  encounterId: number;
  messageId?: number;
  scheduledFor: string;
  status: 'PROGRAMADO' | 'ENVIADO' | 'RESPONDIDO' | 'ALERTA' | 'REVISADO' | 'CERRADO';
  response?: string;
  classification?: string;
  alertReason?: string;
  reviewedBy?: number;
  reviewedAt?: string;
  version: number;
}
