import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { ClinicalEncounter, ClinicalPayload, ClinicalStatus } from '../models/clinical.models';

@Injectable({ providedIn: 'root' })
export class ClinicalApiService {
  private readonly http = inject(HttpClient);
  private readonly base = '/api/v1/clinical-encounters';
  search(from?: string, to?: string, status?: ClinicalStatus, patientId?: number) {
    let params = new HttpParams();
    if (from) params = params.set('from', from); if (to) params = params.set('to', to);
    if (status) params = params.set('status', status); if (patientId) params = params.set('patientId', patientId);
    return this.http.get<ClinicalEncounter[]>(this.base, { params });
  }
  get(id: number) { return this.http.get<ClinicalEncounter>(`${this.base}/${id}`); }
  start(patientId: number, appointmentId?: number) { return this.http.post<ClinicalEncounter>(this.base, { patientId, appointmentId: appointmentId ?? null }); }
  update(id: number, payload: ClinicalPayload) { return this.http.put<ClinicalEncounter>(`${this.base}/${id}`, payload); }
  finalize(id: number, version: number) { return this.http.post<ClinicalEncounter>(`${this.base}/${id}/finalize`, { version, confirmProfessionalApproval: true }); }
}
