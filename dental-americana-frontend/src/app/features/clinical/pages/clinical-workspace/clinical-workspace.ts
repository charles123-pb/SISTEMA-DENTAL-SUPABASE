import { DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  LucideActivity, LucideAlertTriangle, LucideArrowLeft, LucideCalendarDays, LucideCheck,
  LucideClipboardCheck, LucideFileHeart, LucideHeartPulse, LucideHistory, LucideLoaderCircle,
  LucideSave, LucideSearch, LucideShieldAlert, LucideStethoscope,
} from '@lucide/angular';
import { forkJoin } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { AppointmentApiService } from '../../../appointments/data-access/appointment-api.service';
import { Appointment } from '../../../appointments/models/appointment.models';
import { PatientApiService } from '../../../patients/data-access/patient-api.service';
import { PatientDetail, PatientSummary } from '../../../patients/models/patient.models';
import { ClinicalApiService } from '../../data-access/clinical-api.service';
import { ClinicalEncounter, ClinicalPayload } from '../../models/clinical.models';

type ClinicalTab = 'anamnesis' | 'vitals' | 'exam' | 'assessment' | 'closure';

@Component({
  selector: 'app-clinical-workspace',
  imports: [ReactiveFormsModule, RouterLink, DatePipe, LucideActivity, LucideAlertTriangle,
    LucideArrowLeft, LucideCalendarDays, LucideCheck, LucideClipboardCheck, LucideFileHeart,
    LucideHeartPulse, LucideHistory, LucideLoaderCircle, LucideSave, LucideSearch,
    LucideShieldAlert, LucideStethoscope],
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
  private searchTimer?: ReturnType<typeof setTimeout>;

  readonly activeAllergies = computed(() => this.patient()?.allergies.filter((item) => item.status === 'ACTIVA') ?? []);
  readonly worklist = computed(() => this.appointments().filter((item) => !['CANCELADA', 'NO_ASISTIO', 'COMPLETADA'].includes(item.status)));
  readonly completion = computed(() => {
    const form = this.form.getRawValue();
    const required = [form.consultationReason, form.dentalExam, form.diagnosis, form.workPlan, form.patientConsent];
    return Math.round(required.filter(Boolean).length / required.length * 100);
  });

  readonly form = this.fb.group({
    consultationReason: ['', Validators.maxLength(1000)], illnessDuration: ['', Validators.maxLength(250)],
    signsSymptoms: ['', Validators.maxLength(1500)], chronologicalStory: [''],
    systolicPressure: this.fb.control<number | null>(null, [Validators.min(40), Validators.max(300)]),
    diastolicPressure: this.fb.control<number | null>(null, [Validators.min(20), Validators.max(200)]),
    pulse: this.fb.control<number | null>(null, [Validators.min(20), Validators.max(250)]),
    temperature: this.fb.control<number | null>(null, [Validators.min(30), Validators.max(45)]),
    respiratoryRate: this.fb.control<number | null>(null, [Validators.min(5), Validators.max(80)]),
    weightKg: this.fb.control<number | null>(null, [Validators.min(.5), Validators.max(500)]),
    heightCm: this.fb.control<number | null>(null, [Validators.min(20), Validators.max(250)]),
    generalExam: [''], dentalExam: [''], diagnosis: [''], workPlan: [''], prognosis: ['', Validators.maxLength(500)],
    evolution: [''], instructions: [''], nextControlDate: [''], discharged: [false],
    dischargeObservation: ['', Validators.maxLength(1000)], patientConsent: [false],
  });

  ngOnInit(): void { this.loadWorkday(); }
  hasEncounter(appointmentId: number): boolean { return this.encounters().some((item) => item.appointmentId === appointmentId); }

  loadWorkday(): void {
    const start = new Date(); start.setHours(0, 0, 0, 0); const end = new Date(start); end.setDate(end.getDate() + 1);
    this.loading.set(true); this.error.set('');
    forkJoin({ appointments: this.appointmentApi.list(start.toISOString(), end.toISOString()),
      encounters: this.clinicalApi.search(start.toISOString(), end.toISOString()) }).subscribe({
      next: ({ appointments, encounters }) => { this.appointments.set(appointments); this.encounters.set(encounters); this.loading.set(false); },
      error: () => { this.loading.set(false); this.error.set('No se pudo cargar la jornada clínica.'); },
    });
  }

  openAppointment(item: Appointment): void {
    const existing = this.encounters().find((encounter) => encounter.appointmentId === item.id);
    if (existing) { this.open(existing); return; }
    if (!this.canWrite()) { this.error.set('No tienes permiso para iniciar una atención.'); return; }
    this.start(item.patientId, item.id);
  }

  searchPatient(query: string): void {
    clearTimeout(this.searchTimer); this.searchResults.set([]);
    if (query.trim().length < 2) return;
    this.searchTimer = setTimeout(() => {
      this.searching.set(true);
      this.patientApi.search({ q: query.trim(), active: true, page: 0, size: 6 }).subscribe({
        next: (result) => { this.searchResults.set(result.content); this.searching.set(false); },
        error: () => { this.searching.set(false); this.searchResults.set([]); },
      });
    }, 250);
  }

  startWalkIn(patient: PatientSummary): void { this.searchResults.set([]); this.start(patient.id); }

  open(encounter: ClinicalEncounter): void {
    this.current.set(encounter); this.tab.set('anamnesis'); this.error.set(''); this.success.set('');
    this.patch(encounter); this.patientApi.get(encounter.patientId).subscribe({ next: (patient) => this.patient.set(patient) });
  }

  close(): void { this.current.set(null); this.patient.set(null); this.form.reset(); this.clearMessages(); }
  setTab(tab: ClinicalTab): void { this.tab.set(tab); }

  save(): void {
    const current = this.current(); if (!current || current.status !== 'BORRADOR') return;
    if (this.form.invalid) { this.form.markAllAsTouched(); this.error.set('Revisa los valores clínicos fuera de rango.'); return; }
    this.saving.set(true); this.clearMessages();
    this.clinicalApi.update(current.id, this.payload(current.version)).subscribe({
      next: (updated) => { this.current.set(updated); this.patch(updated); this.saving.set(false); this.success.set('Borrador clínico guardado y versionado.'); this.replaceEncounter(updated); },
      error: (error: HttpErrorResponse) => this.handleError(error, 'No se pudo guardar el borrador.'),
    });
  }

  finalize(): void {
    const current = this.current(); if (!current || !this.canApprove()) return;
    if (this.form.dirty) { this.error.set('Guarda los cambios antes de finalizar la atención.'); return; }
    if (this.completion() < 100) { this.error.set('Completa motivo, examen odontológico, diagnóstico, plan y conformidad.'); return; }
    if (!window.confirm('Al finalizar, la historia quedará cerrada y solo podrá consultarse. ¿Confirmas la aprobación profesional?')) return;
    this.saving.set(true); this.clearMessages();
    this.clinicalApi.finalize(current.id, current.version).subscribe({
      next: (updated) => { this.current.set(updated); this.patch(updated); this.saving.set(false); this.success.set('Historia clínica finalizada y aprobada.'); this.replaceEncounter(updated); },
      error: (error: HttpErrorResponse) => this.handleError(error, 'No se pudo finalizar la atención.'),
    });
  }

  private start(patientId: number, appointmentId?: number): void {
    this.saving.set(true); this.clearMessages();
    this.clinicalApi.start(patientId, appointmentId).subscribe({
      next: (encounter) => { this.saving.set(false); this.encounters.update((items) => [encounter, ...items.filter((item) => item.id !== encounter.id)]); this.open(encounter); },
      error: (error: HttpErrorResponse) => this.handleError(error, 'No se pudo iniciar la atención.'),
    });
  }

  private payload(version: number): ClinicalPayload {
    const value = this.form.getRawValue(); const text = (item: string | null) => item?.trim() || null;
    return { consultationReason: text(value.consultationReason), illnessDuration: text(value.illnessDuration),
      signsSymptoms: text(value.signsSymptoms), chronologicalStory: text(value.chronologicalStory),
      systolicPressure: value.systolicPressure, diastolicPressure: value.diastolicPressure, pulse: value.pulse,
      temperature: value.temperature, respiratoryRate: value.respiratoryRate, weightKg: value.weightKg,
      heightCm: value.heightCm, generalExam: text(value.generalExam), dentalExam: text(value.dentalExam),
      diagnosis: text(value.diagnosis), workPlan: text(value.workPlan), prognosis: text(value.prognosis),
      evolution: text(value.evolution), instructions: text(value.instructions), nextControlDate: text(value.nextControlDate),
      discharged: Boolean(value.discharged), dischargeObservation: text(value.dischargeObservation),
      patientConsent: Boolean(value.patientConsent), version };
  }

  private patch(item: ClinicalEncounter): void {
    this.form.reset({ consultationReason: item.consultationReason ?? '', illnessDuration: item.illnessDuration ?? '',
      signsSymptoms: item.signsSymptoms ?? '', chronologicalStory: item.chronologicalStory ?? '',
      systolicPressure: item.systolicPressure ?? null, diastolicPressure: item.diastolicPressure ?? null,
      pulse: item.pulse ?? null, temperature: item.temperature ?? null, respiratoryRate: item.respiratoryRate ?? null,
      weightKg: item.weightKg ?? null, heightCm: item.heightCm ?? null, generalExam: item.generalExam ?? '',
      dentalExam: item.dentalExam ?? '', diagnosis: item.diagnosis ?? '', workPlan: item.workPlan ?? '',
      prognosis: item.prognosis ?? '', evolution: item.evolution ?? '', instructions: item.instructions ?? '',
      nextControlDate: item.nextControlDate ?? '', discharged: item.discharged, dischargeObservation: item.dischargeObservation ?? '',
      patientConsent: item.patientConsent }, { emitEvent: false });
    if (item.status !== 'BORRADOR') this.form.disable({ emitEvent: false }); else this.form.enable({ emitEvent: false });
    this.form.markAsPristine();
  }
  private replaceEncounter(updated: ClinicalEncounter): void { this.encounters.update((items) => items.map((item) => item.id === updated.id ? updated : item)); }
  private handleError(error: HttpErrorResponse, fallback: string): void { this.saving.set(false); this.error.set(error.error?.message || fallback); }
  private clearMessages(): void { this.error.set(''); this.success.set(''); }
}
