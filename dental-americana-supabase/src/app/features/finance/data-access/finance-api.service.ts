import { inject, Injectable } from '@angular/core';
import { combineLatest, from, map, Observable } from 'rxjs';
import { SupabaseApiService } from '../../../core/supabase/supabase-api.service';
import {
  Account,
  CashSession,
  Expense,
  FinanceDashboard,
  Payment,
  PaymentMethod,
  ReceivableStatus,
} from '../models/finance.models';

@Injectable({ providedIn: 'root' })
export class FinanceApiService {
  private readonly api = inject(SupabaseApiService);
  private readonly supabase = this.api.client;

  methods(): Observable<PaymentMethod[]> {
    return from(
      this.supabase.from('metodos_pago').select('*').eq('activo', true).order('nombre'),
    ).pipe(
      map(({ data, error }) => {
        if (error) this.fail(error, 'No se pudieron consultar los métodos de pago.');
        return (data ?? []).map(
          (x) =>
            ({
              id: x.id,
              code: x.codigo,
              name: x.nombre,
              referenceRequired: x.requiere_referencia,
            }) satisfies PaymentMethod,
        );
      }),
    );
  }
  accounts(status?: ReceivableStatus): Observable<Account[]> {
    return this.read<Account[]>(
      'listar_cuentas',
      { estado_filtro: status ?? null, paciente_id: null },
      [],
    );
  }
  currentCash(): Observable<CashSession | null> {
    return this.read<CashSession | null>('caja_actual', {}, null);
  }
  openCash(openingAmount: number): Observable<CashSession> {
    return this.read<CashSession>('abrir_caja', { monto: openingAmount });
  }
  closeCash(
    id: number,
    countedAmount: number,
    observation: string | null,
    version: number,
  ): Observable<CashSession> {
    return this.read<CashSession>('cerrar_caja', {
      caja_id: id,
      monto_contado: countedAmount,
      observacion: observation,
      version_actual: version,
      confirmacion: true,
    });
  }
  dashboard(fromValue: string, to: string): Observable<FinanceDashboard> {
    return this.read<FinanceDashboard>('resumen_finanzas', { desde: fromValue, hasta: to });
  }
  payments(fromValue: string, to: string): Observable<Payment[]> {
    return this.read<Payment[]>('listar_pagos', { desde: fromValue, hasta: to }, []);
  }
  expenses(fromValue: string, to: string): Observable<Expense[]> {
    return this.read<Expense[]>('listar_gastos', { desde: fromValue, hasta: to }, []);
  }
  pay(
    accountId: number,
    paymentMethodId: number,
    amount: number,
    reference: string | null,
    operationId = crypto.randomUUID(),
  ): Observable<Payment> {
    return this.read<Payment>('registrar_pago', {
      datos: this.toJson({
        accountId,
        paymentMethodId,
        amount,
        reference,
        confirmation: true,
        operationId,
      }),
    });
  }
  expense(
    payload: {
      category: string;
      description: string;
      provider: string | null;
      documentReference: string | null;
      paymentMethodId: number;
      amount: number;
    },
    operationId = crypto.randomUUID(),
  ): Observable<Expense> {
    return this.read<Expense>('registrar_gasto', {
      datos: this.toJson({ ...payload, confirmation: true, operationId }),
    });
  }

  exportReport(fromValue: string, to: string): Observable<Blob> {
    return combineLatest([this.payments(fromValue, to), this.expenses(fromValue, to)]).pipe(
      map(([payments, expenses]) => {
        const rows = [
          'tipo,fecha,detalle,monto',
          ...payments.map(
            (x) => `PAGO,${this.csv(x.registeredAt)},${this.csv(x.receiptNumber)},${x.amount}`,
          ),
          ...expenses.map(
            (x) => `GASTO,${this.csv(x.registeredAt)},${this.csv(x.description)},${x.amount}`,
          ),
        ];
        return new Blob([`\uFEFF${rows.join('\n')}`], { type: 'text/csv;charset=utf-8' });
      }),
    );
  }

  private read<T>(name: string, args: Record<string, unknown>, fallback?: T): Observable<T> {
    const options =
      fallback === undefined
        ? { errorMessage: 'No se pudo completar la operación financiera.' }
        : { errorMessage: 'No se pudo completar la operación financiera.', fallback };
    return this.api.rpc<T>(name, args, options);
  }
  private toJson(value: object) {
    return this.api.toJson(value);
  }
  private csv(value: string) {
    return `"${String(value).replaceAll('"', '""')}"`;
  }
  private fail(error: unknown, fallback: string): never {
    return this.api.fail(error, fallback);
  }
}
