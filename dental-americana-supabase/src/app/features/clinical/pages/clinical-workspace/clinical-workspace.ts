import { DatePipe } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  OnInit,
  computed,
  inject,
  signal,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  LucideActivity,
  LucideAlertTriangle,
  LucideArrowLeft,
  LucideCalendarDays,
  LucideCheck,
  LucideClipboardCheck,
  LucideFileHeart,
  LucideHeartPulse,
  LucideHistory,
  LucideLoaderCircle,
  LucideSave,
  LucideSearch,
  LucideShieldAlert,
  LucideStethoscope,
} from '@lucide/angular';
import { forkJoin } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { canLeaveEditor, protectBeforeUnload } from '../../../../core/navigation/pending-changes.guard';
import { SupabaseErrorService } from '../../../../core/supabase/supabase-error.service';
import { AppointmentApiService } from '../../../appointments/data-access/appointment-api.service';
import { Appointment } from '../../../appointments/models/appointment.models';
import { PatientApiService } from '../../../patients/data-access/patient-api.service';
import { PatientDetail, PatientSummary } from '../../../patients/models/patient.models';
import { ClinicalApiService } from '../../data-access/clinical-api.service';
import { ClinicalEncounter, ClinicalPayload } from '../../models/clinical.models';

type ClinicalTab = 'anamnesis' | 'vitals' | 'exam' | 'assessment' | 'closure';

@Component({
  selector: 'app-clinical-workspace',
  host: { '(window:beforeunload)': 'beforeUnload($event)' },
  imports: [
    ReactiveFormsModule,
    RouterLink,
    DatePipe,
    LucideActivity,
    LucideAlertTriangle,
    LucideArrowLeft,
    LucideCalendarDays,
    LucideCheck,
    LucideClipboardCheck,
    LucideFileHeart,
    LucideHeartPulse,
    LucideHistory,
    LucideLoaderCircle,
    LucideSave,
    LucideSearch,
    LucideShieldAlert,
    LucideStethoscope,
  ],
  templateUrl: './clinical-workspace.html',
  styleUrl: './clinical-workspace.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ClinicalWorkspace implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly clinicalApi = inject(ClinicalApiService);
  private readonly appointmentApi = inject(AppointmentApiService);
  private readonly patientApi = inject(PatientApiService);
  private readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly destroyRef = inject(DestroyRef);
  private readonly errors = inject(SupabaseErrorService);

  readonly appointments = signal<Appointment[]>([]);
  readonly encounters = signal<ClinicalEncounter[]>([]);
  readonly current = signal<ClinicalEncounter | null>(null);
  readonly patient = signal<PatientDetail | null>(null);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal('');
  readonly success = signal('');
  readonly tab = signal<ClinicalTab>('anamnesis');
  readonly searchResults = signal<PatientSummary[]>([]);
  readonly searching = signal(false);
  readonly canWrite = signal(this.auth.hasPermission('CLINICA_ESCRIBIR'));
  readonly canApprove = signal(this.auth.hasPermission('CLINICA_APROBAR'));
  readonly canFinance = this.auth.hasPermission('FINANZA_LEER');
  readonly canSchedule = this.auth.hasPermission('CITA_ESCRIBIR');
  readonly canTreatment = this.auth.hasPermission('TRATAMIENTO_LEER');
  private searchTimer?: ReturnType<typeof setTimeout>;
  private workdayRequestId = 0;
  private searchRequestId = 0;
  private patientRequestId = 0;

  readonly activeAllergies = computed(
    () => this.patient()?.allergies.filter((item) => item.status === 'ACTIVA') ?? [],
  );
  readonly worklist = computed(() =>
    this.appointments().filter(
      (item) => !['CANCELADA', 'NO_ASISTIO', 'COMPLETADA'].includes(item.status),
    ),
  );
  completion(): number {
    const form = this.form.getRawValue();
    const required = [
      form.consultationReason,
      form.dentalExam,
      form.diagnosis,
      form.workPlan,
      form.patientConsent,
    ];
    return Math.round((required.filter(Boolean).length / required.length) * 100);
  }

  readonly form = this.fb.group({
    consultationReason: ['', Validators.maxLength(1000)],
    illnessDuration: ['', Validators.maxLength(250)],
    signsSymptoms: ['', Validators.maxLength(1500)],
    chronologicalStory: ['', Validators.maxLength(4000)],
    systolicPressure: this.fb.control<number | null>(null, [
      Validators.min(40),
      Validators.max(300),
    ]),
    diastolicPressure: this.fb.control<number | null>(null, [
      Validators.min(20),
      Validators.max(200),
    ]),
    pulse: this.fb.control<number | null>(null, [Validators.min(20), Validators.max(250)]),
    temperature: this.fb.control<number | null>(null, [Validators.min(30), Validators.max(45)]),
    respiratoryRate: this.fb.control<number | null>(null, [Validators.min(5), Validators.max(80)]),
    weightKg: this.fb.control<number | null>(null, [Validators.min(0.5), Validators.max(500)]),
    heightCm: this.fb.control<number | null>(null, [Validators.min(20), Validators.max(250)]),
    generalExam: ['', Validators.maxLength(4000)],
    dentalExam: ['', Validators.maxLength(4000)],
    diagnosis: ['', Validators.maxLength(4000)],
    workPlan: ['', Validators.maxLength(4000)],
    prognosis: ['', Validators.maxLength(500)],
    evolution: ['', Validators.maxLength(4000)],
    instructions: ['', Validators.maxLength(4000)],
    nextControlDate: [''],
    discharged: [false],
    dischargeObservation: ['', Validators.maxLength(1000)],
    patientConsent: [false],
  });

  ngOnInit(): void {
    this.destroyRef.onDestroy(() => {
      clearTimeout(this.searchTimer);
      this.workdayRequestId++;
      this.searchRequestId++;
      this.patientRequestId++;
    });
    this.loadWorkday();
    const encounterId = Number(this.route.snapshot.queryParamMap.get('encounterId'));
    if (Number.isSafeInteger(encounterId) && encounterId > 0) {
      this.clinicalApi.get(encounterId).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
        next: (encounter) => this.open(encounter),
        error: (error: unknown) => this.error.set(this.errors.toUserMessage(error, 'No se pudo recuperar la atención.')),
      });
      return;
    }
    const appointmentId = Number(this.route.snapshot.queryParamMap.get('appointmentId'));
    if (appointmentId > 0) {
      this.appointmentApi
        .get(appointmentId)
        .pipe(takeUntilDestroyed(this.destroyRef))
        .subscribe({
          next: (appointment) => this.openAppointment(appointment),
          error: (error: unknown) =>
            this.error.set(
              this.errors.toUserMessage(error, 'No se pudo abrir la cita seleccionada.'),
            ),
        });
    }
  }
  hasEncounter(appointmentId: number): boolean {
    return this.encounters().some((item) => item.appointmentId === appointmentId);
  }

  loadWorkday(): void {
    const requestId = ++this.workdayRequestId;
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);
    this.loading.set(true);
    this.error.set('');
    forkJoin({
      appointments: this.appointmentApi.list(start.toISOString(), end.toISOString()),
      encounters: this.clinicalApi.search(start.toISOString(), end.toISOString()),
    })
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: ({ appointments, encounters }) => {
          if (requestId !== this.workdayRequestId) return;
          this.appointments.set(appointments);
          this.encounters.set(encounters);
          this.loading.set(false);
        },
        error: (error: unknown) => {
          if (requestId !== this.workdayRequestId) return;
          this.loading.set(false);
          this.error.set(this.errors.toUserMessage(error, 'No se pudo cargar la jornada clínica.'));
        },
      });
  }

  openAppointment(item: Appointment): void {
    if (this.current()?.appointmentId === item.id) return;
    const existing = this.encounters().find((encounter) => encounter.appointmentId === item.id);
    if (existing) {
      this.open(existing);
      return;
    }
    if (!this.canWrite()) {
      this.error.set('No tienes permiso para iniciar una atención.');
      return;
    }
    this.start(item.patientId, item.id);
  }

  searchPatient(query: string): void {
    const requestId = ++this.searchRequestId;
    clearTimeout(this.searchTimer);
    this.searchResults.set([]);
    this.searching.set(false);
    if (query.trim().length < 2) return;
    this.searchTimer = setTimeout(() => {
      this.searching.set(true);
      this.patientApi
        .search({ q: query.trim(), active: true, page: 0, size: 6 })
        .pipe(takeUntilDestroyed(this.destroyRef))
        .subscribe({
          next: (result) => {
            if (requestId !== this.searchRequestId) return;
            this.searchResults.set(result.content);
            this.searching.set(false);
          },
          error: () => {
            if (requestId !== this.searchRequestId) return;
            this.searching.set(false);
            this.searchResults.set([]);
          },
        });
    }, 250);
  }

  startWalkIn(patient: PatientSummary): void {
    this.searchResults.set([]);
    this.start(patient.id);
  }

  open(encounter: ClinicalEncounter): void {
    if (this.current()?.id === encounter.id || !canLeaveEditor(this)) return;
    this.displayEncounter(encounter);
  }

  private displayEncounter(encounter: ClinicalEncounter): void {
    const requestId = ++this.patientRequestId;
    this.current.set(encounter);
    this.tab.set('anamnesis');
    this.error.set('');
    this.success.set('');
    this.patient.set(null);
    this.patch(encounter);
    this.patientApi
      .get(encounter.patientId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (patient) => {
          if (requestId === this.patientRequestId) this.patient.set(patient);
        },
        error: (error: unknown) => {
          if (requestId === this.patientRequestId)
            this.error.set(
              this.errors.toUserMessage(error, 'No se pudo cargar la ficha del paciente.'),
            );
        },
      });
  }

  close(): void {
    if (!canLeaveEditor(this)) return;
    this.patientRequestId++;
    this.current.set(null);
    this.patient.set(null);
    this.form.reset();
    this.clearMessages();
  }
  setTab(tab: ClinicalTab): void {
    this.tab.set(tab);
  }

  hasUnsavedChanges(): boolean {
    return this.current()?.status === 'BORRADOR' && this.form.dirty;
  }
  isSavingChanges(): boolean { return this.saving(); }
  beforeUnload(event: Event): void { protectBeforeUnload(event, this); }

  save(): void {
    const current = this.current();
    if (!current || current.status !== 'BORRADOR') return;
    if (!this.canWrite() || this.saving()) return;
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      this.error.set('Revisa los valores clínicos fuera de rango.');
      return;
    }
    this.saving.set(true);
    this.clearMessages();
    this.clinicalApi
      .update(current.id, this.payload(current.version))
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (updated) => {
          this.current.set(updated);
          this.patch(updated);
          this.saving.set(false);
          this.success.set('Borrador clínico guardado y versionado.');
          this.replaceEncounter(updated);
        },
        error: (error: unknown) => this.handleError(error, 'No se pudo guardar el borrador.'),
      });
  }

  finalize(): void {
    const current = this.current();
    if (!current || !this.canApprove()) return;
    if (current.status !== 'BORRADOR' || this.saving()) return;
    if (this.form.dirty) {
      this.error.set('Guarda los cambios antes de finalizar la atención.');
      return;
    }
    if (this.completion() < 100) {
      this.error.set('Completa motivo, examen odontológico, diagnóstico, plan y conformidad.');
      return;
    }
    if (
      !window.confirm(
        'Al finalizar, la historia quedará cerrada y solo podrá consultarse. ¿Confirmas la aprobación profesional?',
      )
    )
      return;
    this.saving.set(true);
    this.clearMessages();
    this.clinicalApi
      .finalize(current.id, current.version)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (updated) => {
          this.current.set(updated);
          this.patch(updated);
          this.saving.set(false);
          this.success.set('Historia clínica finalizada y aprobada.');
          this.replaceEncounter(updated);
        },
        error: (error: unknown) => this.handleError(error, 'No se pudo finalizar la atención.'),
      });
  }

  private start(patientId: number, appointmentId?: number): void {
    if (this.saving() || !this.canWrite()) return;
    if (!canLeaveEditor(this)) return;
    this.saving.set(true);
    this.clearMessages();
    this.clinicalApi
      .start(patientId, appointmentId)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (encounter) => {
          this.saving.set(false);
          this.encounters.update((items) => [
            encounter,
            ...items.filter((item) => item.id !== encounter.id),
          ]);
          this.displayEncounter(encounter);
        },
        error: (error: unknown) => this.handleError(error, 'No se pudo iniciar la atención.'),
      });
  }

  private payload(version: number): ClinicalPayload {
    const value = this.form.getRawValue();
    const text = (item: string | null) => item?.trim() || null;
    return {
      consultationReason: text(value.consultationReason),
      illnessDuration: text(value.illnessDuration),
      signsSymptoms: text(value.signsSymptoms),
      chronologicalStory: text(value.chronologicalStory),
      systolicPressure: value.systolicPressure,
      diastolicPressure: value.diastolicPressure,
      pulse: value.pulse,
      temperature: value.temperature,
      respiratoryRate: value.respiratoryRate,
      weightKg: value.weightKg,
      heightCm: value.heightCm,
      generalExam: text(value.generalExam),
      dentalExam: text(value.dentalExam),
      diagnosis: text(value.diagnosis),
      workPlan: text(value.workPlan),
      prognosis: text(value.prognosis),
      evolution: text(value.evolution),
      instructions: text(value.instructions),
      nextControlDate: text(value.nextControlDate),
      discharged: Boolean(value.discharged),
      dischargeObservation: text(value.dischargeObservation),
      patientConsent: Boolean(value.patientConsent),
      version,
    };
  }

  private patch(item: ClinicalEncounter): void {
    this.form.reset(
      {
        consultationReason: item.consultationReason ?? '',
        illnessDuration: item.illnessDuration ?? '',
        signsSymptoms: item.signsSymptoms ?? '',
        chronologicalStory: item.chronologicalStory ?? '',
        systolicPressure: item.systolicPressure ?? null,
        diastolicPressure: item.diastolicPressure ?? null,
        pulse: item.pulse ?? null,
        temperature: item.temperature ?? null,
        respiratoryRate: item.respiratoryRate ?? null,
        weightKg: item.weightKg ?? null,
        heightCm: item.heightCm ?? null,
        generalExam: item.generalExam ?? '',
        dentalExam: item.dentalExam ?? '',
        diagnosis: item.diagnosis ?? '',
        workPlan: item.workPlan ?? '',
        prognosis: item.prognosis ?? '',
        evolution: item.evolution ?? '',
        instructions: item.instructions ?? '',
        nextControlDate: item.nextControlDate ?? '',
        discharged: item.discharged,
        dischargeObservation: item.dischargeObservation ?? '',
        patientConsent: item.patientConsent,
      },
      { emitEvent: false },
    );
    if (item.status !== 'BORRADOR') this.form.disable({ emitEvent: false });
    else this.form.enable({ emitEvent: false });
    this.form.markAsPristine();
  }
  private replaceEncounter(updated: ClinicalEncounter): void {
    this.encounters.update((items) =>
      items.map((item) => (item.id === updated.id ? updated : item)),
    );
  }
  private handleError(error: unknown, fallback: string): void {
    this.saving.set(false);
    this.error.set(this.errors.toUserMessage(error, fallback));
  }
  private clearMessages(): void {
    this.error.set('');
    this.success.set('');
  }
}
