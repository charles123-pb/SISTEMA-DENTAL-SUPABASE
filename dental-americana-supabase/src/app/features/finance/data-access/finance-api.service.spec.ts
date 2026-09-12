import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { SupabaseClientService } from '../../../core/supabase/supabase-client.service';
import { FinanceApiService } from './finance-api.service';

describe('FinanceApiService', () => {
  let service: FinanceApiService;
  let rpc: ReturnType<typeof vi.fn>;
  beforeEach(() => {
    rpc = vi.fn(() => Promise.resolve({ data: { id: 1 }, error: null }));
    TestBed.configureTestingModule({
      providers: [{ provide: SupabaseClientService, useValue: { client: { rpc } } }],
    });
    service = TestBed.inject(FinanceApiService);
  });

  it('requires explicit confirmation when registering a payment', async () => {
    const operationId = '20d1d332-5a31-4b8b-8a8c-a14ebd492e4f';
    await firstValueFrom(service.pay(7, 2, 150, 'YAPE-1', operationId));
    expect(rpc).toHaveBeenCalledWith('registrar_pago', {
      datos: {
        accountId: 7,
        paymentMethodId: 2,
        amount: 150,
        reference: 'YAPE-1',
        confirmation: true,
        operationId,
      },
    });
  });

  it('uses an idempotency key when registering an expense', async () => {
    const operationId = '1553d2fc-b320-4ba0-9f72-a72ece1153d4';
    await firstValueFrom(
      service.expense(
        {
          category: 'Insumos',
          description: 'Guantes',
          provider: null,
          documentReference: 'YAPE-22',
          paymentMethodId: 2,
          amount: 50,
        },
        operationId,
      ),
    );
    expect(rpc).toHaveBeenCalledWith('registrar_gasto', {
      datos: {
        category: 'Insumos',
        description: 'Guantes',
        provider: null,
        documentReference: 'YAPE-22',
        paymentMethodId: 2,
        amount: 50,
        confirmation: true,
        operationId,
      },
    });
  });

  it('requires confirmation and version when closing cash', async () => {
    await firstValueFrom(service.closeCash(3, 480, 'Conforme', 5));
    expect(rpc).toHaveBeenCalledWith('cerrar_caja', {
      caja_id: 3,
      monto_contado: 480,
      observacion: 'Conforme',
      version_actual: 5,
      confirmacion: true,
    });
  });
});
