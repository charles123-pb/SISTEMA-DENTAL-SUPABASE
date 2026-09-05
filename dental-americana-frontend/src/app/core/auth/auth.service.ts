import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { tap } from 'rxjs';
import { CurrentUser, LoginResponse } from './auth.models';

const TOKEN_KEY = 'dental_americana_access_token';
const USER_KEY = 'dental_americana_current_user';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  readonly token = signal<string | null>(localStorage.getItem(TOKEN_KEY));
  readonly currentUser = signal<CurrentUser | null>(this.restoreUser());
  readonly authenticated = computed(() => Boolean(this.token() && this.currentUser()));

  login(username: string, password: string) {
    return this.http.post<LoginResponse>('/api/v1/auth/login', { username, password }).pipe(
      tap((response) => this.saveSession(response)),
    );
  }

  logout(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    this.token.set(null);
    this.currentUser.set(null);
  }

  hasPermission(permission: string): boolean {
    return this.currentUser()?.permissions.includes(permission) ?? false;
  }

  private saveSession(response: LoginResponse): void {
    localStorage.setItem(TOKEN_KEY, response.accessToken);
    localStorage.setItem(USER_KEY, JSON.stringify(response.user));
    this.token.set(response.accessToken);
    this.currentUser.set(response.user);
  }

  private restoreUser(): CurrentUser | null {
    const saved = localStorage.getItem(USER_KEY);
    if (!saved) return null;
    try { return JSON.parse(saved) as CurrentUser; }
    catch { localStorage.removeItem(USER_KEY); return null; }
  }
}
