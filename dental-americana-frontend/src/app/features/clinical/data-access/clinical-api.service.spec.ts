import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ClinicalApiService } from './clinical-api.service';

describe('ClinicalApiService', () => {
  let service: ClinicalApiService; let http: HttpTestingController;
  beforeEach(() => { TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] }); service = TestBed.inject(ClinicalApiService); http = TestBed.inject(HttpTestingController); });
  afterEach(() => http.verify());

  it('starts a walk-in encounter without inventing an appointment', () => {
    service.start(24).subscribe();
    const request = http.expectOne('/api/v1/clinical-encounters');
    expect(request.request.body).toEqual({ patientId: 24, appointmentId: null });
    request.flush({});
  });

  it('requires explicit professional confirmation when finalizing', () => {
    service.finalize(7, 4).subscribe();
    const request = http.expectOne('/api/v1/clinical-encounters/7/finalize');
    expect(request.request.body).toEqual({ version: 4, confirmProfessionalApproval: true });
    request.flush({});
  });
});
