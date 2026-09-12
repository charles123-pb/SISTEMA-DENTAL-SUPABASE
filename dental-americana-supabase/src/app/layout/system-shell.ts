import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { LucideBell, LucideBot, LucideCalendarDays, LucideLayoutDashboard, LucideLogOut, LucideMenu, LucideMessageCircle, LucideSearch, LucideSettings, LucideStethoscope, LucideUsers, LucideWalletCards } from '@lucide/angular';
import { AuthService } from '../core/auth/auth.service';

@Component({
  selector: 'app-system-shell',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, LucideBell, LucideBot, LucideCalendarDays, LucideLayoutDashboard, LucideLogOut, LucideMenu, LucideMessageCircle, LucideSearch, LucideSettings, LucideStethoscope, LucideUsers, LucideWalletCards],
  templateUrl: './system-shell.html',
  styleUrl: './system-shell.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SystemShell {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  readonly menuOpen = signal(false);
  readonly user = this.auth.currentUser;
  readonly canUseAgenda = computed(() => this.auth.hasPermission('CITA_LEER'));
  readonly canUsePatients = computed(() => this.auth.hasPermission('PACIENTE_LEER'));
  readonly canUseClinical = computed(() => this.auth.hasPermission('CLINICA_LEER'));
  readonly canUseFinance = computed(() => this.auth.hasPermission('FINANZA_LEER'));
  readonly canUseFollowUp = computed(() => this.auth.hasPermission('SEGUIMIENTO_LEER'));
  readonly canUseCopilot = computed(() => this.auth.hasPermission('IA_LEER'));
  readonly canUseAdmin = computed(() => this.auth.hasPermission('USUARIO_LEER'));
  readonly initials = computed(() => this.user()?.fullName.split(/\s+/).slice(0, 2).map((word) => word[0]).join('').toUpperCase() || 'DA');
  readonly role = computed(() => this.user()?.roles[0]?.replaceAll('_', ' ') || 'Personal');

  searchPatient(value: string): void {
    const query = value.trim();
    if (!query) return;
    void this.router.navigate(['/sistema/pacientes'], { queryParams: { q: query } });
  }

  logout(): void {
    this.auth.logout();
    void this.router.navigate(['/sistema/login']);
  }
}
