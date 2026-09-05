import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Appointment, AppointmentPayload, AppointmentStatus, AppointmentType, AvailabilitySlot, Professional } from '../models/appointment.models';

@Injectable({ providedIn: 'root' })
export class AppointmentApiService {
  private readonly http = inject(HttpClient);
  private readonly base = '/api/v1/appointments';

  list(from: string, to: string, professionalId?: number, status?: AppointmentStatus | '') {
    let params = new HttpParams().set('from', from).set('to', to);
    if (professionalId) params = params.set('professionalId', professionalId);
    if (status) params = params.set('status', status);
    return this.http.get<Appointment[]>(this.base, { params });
  }
  get(id: number) { return this.http.get<Appointment>(`${this.base}/${id}`); }
  types() { return this.http.get<AppointmentType[]>('/api/v1/appointment-types'); }
  professionals() { return this.http.get<Professional[]>(`${this.base}/professionals`); }
  availability(professionalId: number, date: string, appointmentTypeId: number) {
    const params = new HttpParams().set('professionalId', professionalId).set('date', date).set('appointmentTypeId', appointmentTypeId);
    return this.http.get<AvailabilitySlot[]>(`${this.base}/availability`, { params });
  }
  create(payload: AppointmentPayload) { return this.http.post<Appointment>(this.base, payload); }
  update(id: number, payload: AppointmentPayload & { version: number }) { return this.http.put<Appointment>(`${this.base}/${id}`, payload); }
  changeStatus(id: number, status: AppointmentStatus, version: number, reason?: string) {
    return this.http.patch<Appointment>(`${this.base}/${id}/status`, { status, version, reason: reason || null });
  }
}
