import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { SupabaseApiService } from '../../../core/supabase/supabase-api.service';
import { Conversation, FollowUp, Message, WhatsAppSession } from '../models/messaging.models';

@Injectable({ providedIn: 'root' })
export class MessagingApiService {
  private static readonly errorMessage = 'No se pudo completar la operación de WhatsApp.';
  private readonly api = inject(SupabaseApiService);
  private readonly supabase = this.api.client;

  conversations(search = ''): Observable<Conversation[]> {
    return this.rpc<Conversation[]>(
      'listar_conversaciones_whatsapp',
      { busqueda: search || null },
      [],
    );
  }
  conversationMessages(id: number): Observable<Message[]> {
    return this.rpc<Message[]>('listar_mensajes_conversacion', { conversacion_id: id }, []);
  }
  followUps(): Observable<FollowUp[]> {
    return this.rpc<FollowUp[]>('listar_seguimientos', {}, []);
  }
  markRead(id: number): Observable<void> {
    return this.rpc<void>('marcar_conversacion_leida', { conversacion_id: id });
  }
  session(): Observable<WhatsAppSession> {
    return this.invoke<WhatsAppSession>('whatsapp-session', {});
  }
  connect(): Observable<WhatsAppSession> {
    return this.invoke<WhatsAppSession>('whatsapp-session', { action: 'connect' });
  }
  sync(): Observable<{ chats: number; messages: number }> {
    return this.invoke<{ chats: number; messages: number }>('whatsapp-sync', {});
  }
  send(patientId: number, content: string, scheduledFor?: string): Observable<Message> {
    return this.invoke<Message>('whatsapp-send', {
      patientId,
      content,
      scheduledFor: scheduledFor || null,
    });
  }
  retry(messageId: number): Observable<Message> {
    return this.invoke<Message>('whatsapp-send', { retryMessageId: messageId });
  }
  review(id: number, version: number): Observable<FollowUp> {
    return this.rpc<FollowUp>('revisar_seguimiento', {
      seguimiento_id: id,
      version_actual: version,
      confirmacion: true,
    });
  }
  realtime(): Observable<void> {
    return new Observable((subscriber) => {
      const channel = this.supabase
        .channel(`dental-whatsapp-ui-${crypto.randomUUID()}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'mensajes_whatsapp' }, () =>
          subscriber.next(),
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'conversaciones_whatsapp' },
          () => subscriber.next(),
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'whatsapp_instancia_estado' },
          () => subscriber.next(),
        )
        .on('postgres_changes', { event: '*', schema: 'public', table: 'citas' }, () =>
          subscriber.next(),
        )
        .subscribe();
      return () => {
        void this.supabase.removeChannel(channel);
      };
    });
  }
  private invoke<T>(name: string, body: Record<string, unknown>) {
    return this.api.invoke<T>(name, body, {
      errorMessage: MessagingApiService.errorMessage,
    });
  }
  private rpc<T>(name: string, args: Record<string, unknown>, fallback?: T) {
    const options = fallback === undefined
      ? { errorMessage: MessagingApiService.errorMessage }
      : { errorMessage: MessagingApiService.errorMessage, fallback };
    return this.api.rpc<T>(name, args, options);
  }
}
