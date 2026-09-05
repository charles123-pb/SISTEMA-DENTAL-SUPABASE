import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import {
  AuditEntry,
  OperationalSummary,
  PageResult,
  Role,
  Setting,
  UserAccount,
} from '../models/admin.models';
@Injectable({ providedIn: 'root' })
export class AdminApiService {
  private readonly http = inject(HttpClient);
  users() {
    return this.http.get<UserAccount[]>('/api/v1/users');
  }
  roles() {
    return this.http.get<Role[]>('/api/v1/roles');
  }
  createUser(payload: {
    username: string;
    password: string;
    fullName: string;
    email: string | null;
    roles: string[];
  }) {
    return this.http.post<UserAccount>('/api/v1/users', payload);
  }
  status(id: number, active: boolean) {
    return this.http.patch<UserAccount>(`/api/v1/users/${id}/status`, { active });
  }
  changePassword(currentPassword: string, newPassword: string, confirmation: string) {
    return this.http.patch<void>('/api/v1/auth/password', {
      currentPassword,
      newPassword,
      confirmation,
    });
  }
  settings() {
    return this.http.get<Setting[]>('/api/v1/admin/settings');
  }
  updateSetting(key: string, value: string, version: number) {
    return this.http.put<Setting>(`/api/v1/admin/settings/${encodeURIComponent(key)}`, {
      value,
      version,
    });
  }
  audit(from: string, to: string, q = '') {
    let params = new HttpParams().set('from', from).set('to', to).set('page', 0).set('size', 50);
    if (q.trim()) params = params.set('q', q.trim());
    return this.http.get<PageResult<AuditEntry>>('/api/v1/admin/audit', { params });
  }
  summary(from: string, to: string) {
    return this.http.get<OperationalSummary>('/api/v1/admin/summary', {
      params: new HttpParams().set('from', from).set('to', to),
    });
  }
  export(from: string, to: string) {
    return this.http.get('/api/v1/admin/reports/operational.csv', {
      params: new HttpParams().set('from', from).set('to', to),
      responseType: 'blob',
    });
  }
}
