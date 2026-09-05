import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { PatientApiService } from './patient-api.service';
import { PatientPayload } from '../models/patient.models';

describe('PatientApiService', () => {
  let service: PatientApiService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(PatientApiService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('builds patient search filters without empty values', () => {
    service.search({ q: 'Ana', active: true, sex: '', page: 0, size: 20 }).subscribe();
    const request = http.expectOne((item) => item.url === '/api/v1/patients');
    expect(request.request.method).toBe('GET');
    expect(request.request.params.get('q')).toBe('Ana');
    expect(request.request.params.get('active')).toBe('true');
    expect(request.request.params.has('sex')).toBe(false);
    request.flush({ content: [], page: 0, size: 20, totalElements: 0, totalPages: 0, first: true, last: true });
  });

  it('sends the complete payload when creating a patient', () => {
    const payload: PatientPayload = {
      documentType: 'DNI', documentNumber: '12345678', firstNames: 'Ana', paternalSurname: 'Torres',
      maternalSurname: null, birthDate: '1990-05-20', sex: 'FEMENINO', birthPlace: null,
      occupation: null, maritalStatus: null, educationLevel: null, religion: null,
      ethnicSelfIdentification: null, mobile: '940577075', whatsappConsent: true,
      phone: null, email: null, address: null,
      responsibleName: null, responsibleDocument: null, responsibleRelationship: null,
      responsiblePhone: null, emergencyContact: null,
    };
    service.create(payload).subscribe();
    const request = http.expectOne('/api/v1/patients');
    expect(request.request.method).toBe('POST');
    expect(request.request.body.documentNumber).toBe('12345678');
    request.flush({});
  });

  it('requests files as authenticated-compatible blobs', () => {
    service.downloadFile(8, 13).subscribe((response) => expect(response.body).toBeInstanceOf(Blob));
    const request = http.expectOne('/api/v1/patients/8/files/13');
    expect(request.request.responseType).toBe('blob');
    request.flush(new Blob(['contenido'], { type: 'application/pdf' }));
  });
});
