import { DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
  computed,
  inject,
  signal,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import {
  LucideAlertTriangle,
  LucideBot,
  LucideCheck,
  LucideClock3,
  LucideLoaderCircle,
  LucideMessageCircle,
  LucidePlus,
  LucideRefreshCw,
  LucideSearch,
  LucideSend,
  LucideShieldAlert,
  LucideX,
} from '@lucide/angular';
import { forkJoin } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { PatientApiService } from '../../../patients/data-access/patient-api.service';
import { PatientSummary } from '../../../patients/models/patient.models';
import { MessagingApiService } from '../../data-access/messaging-api.service';
import { FollowUp, Message } from '../../models/messaging.models';
type Tab = 'followups' | 'messages';
@Component({
  selector: 'app-follow-up-center',
  imports: [
    ReactiveFormsModule,
    DatePipe,
    LucideAlertTriangle,
    LucideBot,
    LucideCheck,
    LucideClock3,
    LucideLoaderCircle,
    LucideMessageCircle,
    LucidePlus,
    LucideRefreshCw,
    LucideSearch,
    LucideSend,
    LucideShieldAlert,
    LucideX,
  ],
  templateUrl: './follow-up-center.html',
  styleUrl: './follow-up-center.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class FollowUpCenter implements OnInit {
  private readonly fb = inject(FormBuilder).nonNullable;
  private readonly api = inject(MessagingApiService);
  private readonly patientApi = inject(PatientApiService);
  private readonly auth = inject(AuthService);
  readonly followups = signal<FollowUp[]>([]);
  readonly messages = signal<Message[]>([]);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal('');
  readonly success = signal('');
  readonly tab = signal<Tab>('followups');
  readonly compose = signal(false);
  readonly results = signal<PatientSummary[]>([]);
  readonly selectedPatient = signal<PatientSummary | null>(null);
  readonly canWrite = signal(this.auth.hasPermission('SEGUIMIENTO_ESCRIBIR'));
  private timer?: ReturnType<typeof setTimeout>;
  readonly alerts = computed(() => this.followups().filter((f) => f.status === 'ALERTA'));
  readonly pending = computed(() => this.followups().filter((f) => f.status !== 'ALERTA'));
  readonly form = this.fb.group({
    search: [''],
    content: ['', Validators.required],
    scheduledFor: [''],
  });
  ngOnInit() {
    this.load();
  }
  load() {
    this.loading.set(true);
    forkJoin({ followups: this.api.followUps(), messages: this.api.messages() }).subscribe({
      next: (r) => {
        this.followups.set(r.followups);
        this.messages.set(r.messages);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.error.set('No se pudo cargar el seguimiento.');
      },
    });
  }
  search(q: string) {
    clearTimeout(this.timer);
    this.selectedPatient.set(null);
    if (q.trim().length < 2) {
      this.results.set([]);
      return;
    }
    this.timer = setTimeout(
      () =>
        this.patientApi
          .search({ q: q.trim(), active: true, page: 0, size: 6 })
          .subscribe((r) => this.results.set(r.content)),
      250,
    );
  }
  select(p: PatientSummary) {
    if (!p.mobile || !p.whatsappConsent) {
      this.selectedPatient.set(null);
      this.error.set(
        !p.mobile
          ? 'El paciente no tiene celular registrado.'
          : 'El paciente no autorizó comunicaciones por WhatsApp. Actualiza primero su ficha.',
      );
      return;
    }
    this.error.set('');
    this.selectedPatient.set(p);
    this.results.set([]);
    this.form.controls.search.setValue(p.fullName);
  }
  send() {
    const p = this.selectedPatient();
    if (!p || this.form.invalid) {
      this.error.set('Selecciona paciente y escribe el mensaje.');
      return;
    }
    const v = this.form.getRawValue();
    this.run(
      this.api.send(
        p.id,
        v.content.trim(),
        v.scheduledFor ? new Date(v.scheduledFor).toISOString() : undefined,
      ),
      'Mensaje colocado en la cola de envío.',
      () => {
        this.compose.set(false);
        this.form.reset();
        this.selectedPatient.set(null);
      },
    );
  }
  review(f: FollowUp) {
    if (!confirm('¿Confirmas que revisaste profesionalmente esta respuesta?')) return;
    this.run(this.api.review(f.id, f.version), 'Seguimiento revisado.');
  }
  label(v: string) {
    return v.replaceAll('_', ' ').toLowerCase();
  }
  private run<T>(
    req: { subscribe(o: { next(v: T): void; error(e: HttpErrorResponse): void }): unknown },
    msg: string,
    done: () => void = () => {},
  ) {
    this.saving.set(true);
    this.error.set('');
    req.subscribe({
      next: () => {
        this.saving.set(false);
        this.success.set(msg);
        done();
        this.load();
      },
      error: (e) => {
        this.saving.set(false);
        this.error.set(e.error?.message || 'No se pudo completar la acción.');
      },
    });
  }
}
