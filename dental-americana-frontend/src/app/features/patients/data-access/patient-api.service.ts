import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import {
  AllergyPayload, DuplicateCandidate, EmergencyContact, EmergencyContactRequest, HistoryPayload,
  MedicationPayload, PageResponse, PatientAllergy, PatientDetail, PatientFile, PatientFileCategory,
  PatientHistory, PatientMedication, PatientPayload, PatientSex, PatientSummary,
} from '../models/patient.models';

export interface PatientSearch {
  q?: string; active?: boolean; sex?: PatientSex | ''; minAge?: number; maxAge?: number;
  page?: number; size?: number; sort?: string; direction?: 'asc' | 'desc';
}

@Injectable({ providedIn: 'root' })
export class PatientApiService {
  private readonly http = inject(HttpClient);
  private readonly base = '/api/v1/patients';

  search(filter: PatientSearch) {
    let params = new HttpParams();
    Object.entries(filter).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') params = params.set(key, String(value));
    });
    return this.http.get<PageResponse<PatientSummary>>(this.base, { params });
  }
  get(id: number) { return this.http.get<PatientDetail>(`${this.base}/${id}`); }
  create(payload: PatientPayload) { return this.http.post<PatientDetail>(this.base, payload); }
  update(id: number, payload: PatientPayload & { version: number }) { return this.http.put<PatientDetail>(`${this.base}/${id}`, payload); }
  changeStatus(id: number, active: boolean, version: number) { return this.http.patch<PatientDetail>(`${this.base}/${id}/status`, { active, version }); }
  duplicates(documentNumber?: string, mobile?: string, birthDate?: string, paternalSurname?: string) {
    let params = new HttpParams();
    if (documentNumber) params = params.set('documentNumber', documentNumber);
    if (mobile) params = params.set('mobile', mobile);
    if (birthDate) params = params.set('birthDate', birthDate);
    if (paternalSurname) params = params.set('paternalSurname', paternalSurname);
    return this.http.get<DuplicateCandidate[]>(`${this.base}/duplicates`, { params });
  }
  addEmergencyContact(id: number, payload: EmergencyContactRequest) { return this.http.post<EmergencyContact>(`${this.base}/${id}/emergency-contacts`, payload); }
  addHistory(id: number, payload: HistoryPayload) { return this.http.post<PatientHistory>(`${this.base}/${id}/histories`, payload); }
  addAllergy(id: number, payload: AllergyPayload) { return this.http.post<PatientAllergy>(`${this.base}/${id}/allergies`, payload); }
  addMedication(id: number, payload: MedicationPayload) { return this.http.post<PatientMedication>(`${this.base}/${id}/medications`, payload); }
  uploadFile(id: number, file: File, category: PatientFileCategory, description?: string) {
    const body = new FormData();
    body.append('file', file); body.append('category', category);
    if (description) body.append('description', description);
    return this.http.post<PatientFile>(`${this.base}/${id}/files`, body);
  }
  downloadFile(patientId: number, fileId: number) {
    return this.http.get(`${this.base}/${patientId}/files/${fileId}`, { observe: 'response', responseType: 'blob' });
  }
}
