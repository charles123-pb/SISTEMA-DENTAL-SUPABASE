import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { SupabaseClientService } from '../../../core/supabase/supabase-client.service';
import { MessagingApiService } from './messaging-api.service';

describe('MessagingApiService', () => {
  let service: MessagingApiService;
  let rpc: ReturnType<typeof vi.fn>;
  let invoke: ReturnType<typeof vi.fn>;
  beforeEach(() => {
    rpc = vi.fn(() => Promise.resolve({ data: { id: 9 }, error: null }));
    invoke = vi.fn(() => Promise.resolve({ data: { chats: 3, messages: 8 }, error: null }));
    TestBed.configureTestingModule({
      providers: [
        { provide: SupabaseClientService, useValue: { client: { rpc, functions: { invoke } } } },
      ],
    });
    service = TestBed.inject(MessagingApiService);
  });
  it('marks a follow-up as professionally reviewed', async () => {
    await firstValueFrom(service.review(9, 3));
    expect(rpc).toHaveBeenCalledWith('revisar_seguimiento', {
      seguimiento_id: 9,
      version_actual: 3,
      confirmacion: true,
    });
  });
  it('synchronizes the Evolution API history through an Edge Function', async () => {
    await firstValueFrom(service.sync());
    expect(invoke).toHaveBeenCalledWith('whatsapp-sync', { body: {} });
  });

  it('requests a new QR through the protected session function', async () => {
    await firstValueFrom(service.connect());
    expect(invoke).toHaveBeenCalledWith('whatsapp-session', {
      body: { action: 'connect' },
    });
  });

  it('sends manual messages only through the Edge Function', async () => {
    await firstValueFrom(service.send(42, 'Hola paciente'));
    expect(invoke).toHaveBeenCalledWith('whatsapp-send', {
      body: { patientId: 42, content: 'Hola paciente', scheduledFor: null },
    });
  });

  it('retries a failed message by its identifier', async () => {
    await firstValueFrom(service.retry(81));
    expect(invoke).toHaveBeenCalledWith('whatsapp-send', {
      body: { retryMessageId: 81 },
    });
  });

  it('passes the normalized empty search to the conversations RPC', async () => {
    await firstValueFrom(service.conversations());
    expect(rpc).toHaveBeenCalledWith('listar_conversaciones_whatsapp', { busqueda: null });
  });
});
