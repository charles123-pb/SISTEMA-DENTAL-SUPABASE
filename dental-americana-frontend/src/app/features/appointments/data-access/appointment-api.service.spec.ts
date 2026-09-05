import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { AppointmentApiService } from './appointment-api.service';

describe('AppointmentApiService', () => {
  let service: AppointmentApiService;
  let http: HttpTestingController;
  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(AppointmentApiService); http = TestBed.inject(HttpTestingController);
  });
  afterEach(() => http.verify());

  it('requests an agenda range with filters', () => {
    service.list('2026-09-01T05:00:00.000Z', '2026-09-08T05:00:00.000Z', 4, 'CONFIRMADA').subscribe();
    const request = http.expectOne((item) => item.url === '/api/v1/appointments');
    expect(request.request.params.get('professionalId')).toBe('4');
    expect(request.request.params.get('status')).toBe('CONFIRMADA');
    request.flush([]);
  });

  it('sends optimistic version when changing appointment status', () => {
    service.changeStatus(12, 'CANCELADA', 3, 'Paciente solicitó cambio').subscribe();
    const request = http.expectOne('/api/v1/appointments/12/status');
    expect(request.request.method).toBe('PATCH');
    expect(request.request.body).toEqual({ status: 'CANCELADA', version: 3, reason: 'Paciente solicitó cambio' });
    request.flush({});
  });
});
