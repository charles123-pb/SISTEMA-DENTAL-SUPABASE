import { CurrencyPipe, DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import {
  LucideActivity,
  LucideAlertTriangle,
  LucideCheck,
  LucideCircleDollarSign,
  LucideDownload,
  LucideFileClock,
  LucideLoaderCircle,
  LucideLockKeyhole,
  LucidePlus,
  LucideRefreshCw,
  LucideSave,
  LucideSettings,
  LucideShieldCheck,
  LucideUsers,
  LucideX,
} from '@lucide/angular';
import { forkJoin, Observable } from 'rxjs';
import { AdminApiService } from '../../data-access/admin-api.service';
import {
  AuditEntry,
  OperationalSummary,
  Role,
  Setting,
  UserAccount,
} from '../../models/admin.models';
type Tab = 'users' | 'settings' | 'audit' | 'reports';
@Component({
  selector: 'app-admin-center',
  imports: [
    ReactiveFormsModule,
    CurrencyPipe,
    DatePipe,
    LucideActivity,
    LucideAlertTriangle,
    LucideCheck,
    LucideCircleDollarSign,
    LucideDownload,
    LucideFileClock,
    LucideLoaderCircle,
    LucideLockKeyhole,
    LucidePlus,
    LucideRefreshCw,
    LucideSave,
    LucideSettings,
    LucideShieldCheck,
    LucideUsers,
    LucideX,
  ],
  templateUrl: './admin-center.html',
  styleUrl: './admin-center.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AdminCenter implements OnInit {
  private readonly api = inject(AdminApiService);
  private readonly fb = inject(FormBuilder).nonNullable;
  readonly tab = signal<Tab>('users');
  readonly users = signal<UserAccount[]>([]);
  readonly roles = signal<Role[]>([]);
  readonly settings = signal<Setting[]>([]);
  readonly audits = signal<AuditEntry[]>([]);
  readonly summary = signal<OperationalSummary | null>(null);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal('');
  readonly success = signal('');
  readonly createOpen = signal(false);
  readonly selectedRoles = signal<string[]>([]);
  readonly settingDrafts = signal<Record<string, string>>({});
  readonly range = this.defaultRange();
  readonly userForm = this.fb.group({
    fullName: ['', [Validators.required]],
    username: ['', [Validators.required, Validators.minLength(4)]],
    email: ['', [Validators.email]],
    password: ['', [Validators.required, Validators.minLength(10)]],
  });
  readonly passwordForm = this.fb.group({
    currentPassword: ['', Validators.required],
    newPassword: [
      '',
      [Validators.required, Validators.minLength(10), Validators.pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/)],
    ],
    confirmation: ['', Validators.required],
  });
  ngOnInit() {
    this.load();
  }
  load() {
    this.loading.set(true);
    this.error.set('');
    forkJoin({
      users: this.api.users(),
      roles: this.api.roles(),
      settings: this.api.settings(),
      audits: this.api.audit(this.range.from, this.range.to),
      summary: this.api.summary(this.range.from, this.range.to),
    }).subscribe({
      next: (r) => {
        this.users.set(r.users);
        this.roles.set(r.roles);
        if (!this.selectedRoles().length) this.selectedRoles.set(['ODONTOLOGO']);
        this.settings.set(r.settings);
        this.settingDrafts.set(Object.fromEntries(r.settings.map((s) => [s.key, s.value])));
        this.audits.set(r.audits.content);
        this.summary.set(r.summary);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.error.set('No se pudo cargar el centro administrativo.');
      },
    });
  }
  toggleRole(code: string) {
    this.selectedRoles.update((v) =>
      v.includes(code) ? v.filter((x) => x !== code) : [...v, code],
    );
  }
  createUser() {
    if (this.userForm.invalid || !this.selectedRoles().length) {
      this.error.set('Completa los datos y selecciona al menos un rol.');
      return;
    }
    const v = this.userForm.getRawValue();
    this.run(
      this.api.createUser({
        username: v.username.trim(),
        password: v.password,
        fullName: v.fullName.trim(),
        email: v.email.trim() || null,
        roles: this.selectedRoles(),
      }),
      'Usuario creado.',
      () => {
        this.createOpen.set(false);
        this.userForm.reset();
        this.selectedRoles.set([]);
      },
    );
  }
  changeStatus(u: UserAccount) {
    if (!confirm(`¿${u.active ? 'Desactivar' : 'Activar'} a ${u.fullName}?`)) return;
    this.run(this.api.status(u.id, !u.active), 'Estado del usuario actualizado.');
  }
  draft(key: string, value: string) {
    this.settingDrafts.update((v) => ({ ...v, [key]: value }));
  }
  saveSetting(s: Setting) {
    this.run(
      this.api.updateSetting(s.key, this.settingDrafts()[s.key] ?? '', s.version),
      'Configuración guardada.',
    );
  }
  changePassword() {
    const value = this.passwordForm.getRawValue();
    if (this.passwordForm.invalid || value.newPassword !== value.confirmation) {
      this.error.set('La nueva contraseña debe coincidir y contener mayúscula, minúscula y número.');
      return;
    }
    this.run(
      this.api.changePassword(value.currentPassword, value.newPassword, value.confirmation),
      'Contraseña actualizada correctamente.',
      () => this.passwordForm.reset(),
    );
  }
  searchAudit(q: string) {
    this.loading.set(true);
    this.api.audit(this.range.from, this.range.to, q).subscribe({
      next: (r) => {
        this.audits.set(r.content);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.error.set('No se pudo consultar la auditoría.');
      },
    });
  }
  download() {
    this.api.export(this.range.from, this.range.to).subscribe({
      next: (blob) => {
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'Reporte_Dental_Americana.csv';
        a.click();
        URL.revokeObjectURL(a.href);
      },
      error: () => this.error.set('No se pudo exportar el reporte.'),
    });
  }
  label(v: string) {
    return v.replaceAll('_', ' ').toLowerCase();
  }
  private run<T>(request: Observable<T>, message: string, done: () => void = () => {}) {
    this.saving.set(true);
    this.error.set('');
    this.success.set('');
    request.subscribe({
      next: () => {
        this.saving.set(false);
        this.success.set(message);
        done();
        this.load();
      },
      error: (e: HttpErrorResponse) => {
        this.saving.set(false);
        this.error.set(e.error?.message || 'No se pudo completar la acción.');
      },
    });
  }
  private defaultRange() {
    const to = new Date();
    to.setDate(to.getDate() + 1);
    const from = new Date();
    from.setDate(from.getDate() - 30);
    return { from: from.toISOString(), to: to.toISOString() };
  }
}
