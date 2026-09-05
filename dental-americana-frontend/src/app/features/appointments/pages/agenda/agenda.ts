import { DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import {
  LucideAlertTriangle, LucideArrowLeft, LucideArrowRight, LucideCalendarDays,
  LucideCheck, LucideChevronDown, LucideClock3, LucideEdit3, LucideLoaderCircle,
  LucideMessageCircle, LucidePhone, LucidePlus, LucideRefreshCw, LucideSearch,
  LucideSlidersHorizontal, LucideUserRound, LucideX,
} from '@lucide/angular';
import { forkJoin } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { PatientApiService } from '../../../patients/data-access/patient-api.service';
import { PatientSummary } from '../../../patients/models/patient.models';
import { AppointmentApiService } from '../../data-access/appointment-api.service';
import { Appointment, AppointmentStatus, AppointmentType, AvailabilitySlot, Professional } from '../../models/appointment.models';

@Component({
  selector: 'app-agenda',
  imports: [ReactiveFormsModule, RouterLink, DatePipe, LucideAlertTriangle, LucideArrowLeft,
    LucideArrowRight, LucideCalendarDays, LucideCheck, LucideChevronDown, LucideClock3,
    LucideEdit3, LucideLoaderCircle, LucideMessageCircle, LucidePhone, LucidePlus,
    LucideRefreshCw, LucideSearch, LucideSlidersHorizontal, LucideUserRound, LucideX],
  templateUrl: './agenda.html',
  styleUrl: './agenda.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Agenda implements OnInit {
  private readonly fb = inject(FormBuilder).nonNullable;
  private readonly api = inject(AppointmentApiService);
  private readonly patientsApi = inject(PatientApiService);
  private readonly auth = inject(AuthService);

  readonly appointments = signal<Appointment[]>([]);
  readonly types = signal<AppointmentType[]>([]);
  readonly professionals = signal<Professional[]>([]);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal('');
  readonly success = signal('');
  readonly selectedDate = signal(this.dateKey(new Date()));
  readonly professionalFilter = signal<number | undefined>(undefined);
  readonly statusFilter = signal<AppointmentStatus | ''>('');
  readonly modalOpen = signal(false);
  readonly editing = signal<Appointment | null>(null);
  readonly patientResults = signal<PatientSummary[]>([]);
  readonly selectedPatient = signal<PatientSummary | null>(null);
  readonly searchingPatients = signal(false);
  readonly availability = signal<AvailabilitySlot[]>([]);
  readonly loadingSlots = signal(false);
  readonly selectedStart = signal('');
  readonly canWrite = signal(this.auth.hasPermission('CITA_ESCRIBIR'));
  private patientSearchTimer?: ReturnType<typeof setTimeout>;

  readonly weekDays = computed(() => {
    const selected = this.parseDate(this.selectedDate());
    const monday = new Date(selected); const day = monday.getDay() || 7;
    monday.setDate(monday.getDate() - day + 1);
    return Array.from({ length: 7 }, (_, index) => { const value = new Date(monday); value.setDate(monday.getDate() + index); return value; });
  });
  readonly selectedAppointments = computed(() => this.appointments()
    .filter((item) => this.dateKey(new Date(item.start)) === this.selectedDate())
    .sort((a, b) => a.start.localeCompare(b.start)));
  readonly dayCounts = computed(() => new Map(this.weekDays().map((day) => [this.dateKey(day), this.appointments().filter((item) => this.dateKey(new Date(item.start)) === this.dateKey(day)).length])));
  readonly dayLabel = computed(() => this.parseDate(this.selectedDate()));
  readonly summary = computed(() => ({
    total: this.selectedAppointments().length,
    confirmed: this.selectedAppointments().filter((item) => item.status === 'CONFIRMADA').length,
    waiting: this.selectedAppointments().filter((item) => item.status === 'EN_ESPERA' || item.status === 'EN_ATENCION').length,
    pending: this.selectedAppointments().filter((item) => item.status === 'PENDIENTE_CONFIRMACION').length,
  }));

  readonly form = this.fb.group({
    patientSearch: [''], professionalId: this.fb.control<number | null>(null, Validators.required),
    appointmentTypeId: this.fb.control<number | null>(null, Validators.required), date: [this.selectedDate(), Validators.required],
    reason: ['', [Validators.required, Validators.maxLength(500)]], notes: ['', Validators.maxLength(1000)],
  });

  ngOnInit(): void {
    forkJoin({ types: this.api.types(), professionals: this.api.professionals() }).subscribe({
      next: ({ types, professionals }) => { this.types.set(types); this.professionals.set(professionals); this.load(); },
      error: () => { this.loading.set(false); this.error.set('No se pudo cargar la configuración de la agenda.'); },
    });
  }

  load(): void {
    const fromDate = this.weekDays()[0]; const toDate = new Date(this.weekDays()[6]); toDate.setDate(toDate.getDate() + 1);
    this.loading.set(true); this.error.set('');
    this.api.list(fromDate.toISOString(), toDate.toISOString(), this.professionalFilter(), this.statusFilter()).subscribe({
      next: (items) => { this.appointments.set(items); this.loading.set(false); },
      error: () => { this.loading.set(false); this.error.set('No se pudieron cargar las citas de la semana.'); },
    });
  }

  selectDay(date: Date): void { this.selectedDate.set(this.dateKey(date)); }
  moveWeek(delta: number): void { const date = this.parseDate(this.selectedDate()); date.setDate(date.getDate() + delta * 7); this.selectedDate.set(this.dateKey(date)); this.load(); }
  today(): void { this.selectedDate.set(this.dateKey(new Date())); this.load(); }
  applyFilters(professional: string, status: string): void {
    this.professionalFilter.set(professional ? Number(professional) : undefined);
    this.statusFilter.set(status as AppointmentStatus | ''); this.load();
  }

  openNew(): void {
    this.editing.set(null); this.selectedPatient.set(null); this.patientResults.set([]); this.selectedStart.set(''); this.availability.set([]);
    this.form.reset({ patientSearch: '', professionalId: this.professionals()[0]?.id ?? null,
      appointmentTypeId: this.types()[0]?.id ?? null, date: this.selectedDate(), reason: '', notes: '' });
    this.modalOpen.set(true); this.clearMessages(); this.loadSlots();
  }

  openEdit(item: Appointment): void {
    const patient: PatientSummary = { id: item.patientId, historyNumber: item.patientHistoryNumber, documentType: 'SIN_DOCUMENTO',
      fullName: item.patientName, birthDate: '', age: 0, sex: 'NO_ESPECIFICA', mobile: item.patientMobile, whatsappConsent: false,
      activeAllergies: 0, active: true, createdAt: '', version: 0 };
    this.editing.set(item); this.selectedPatient.set(patient); this.selectedStart.set(item.start);
    this.form.reset({ patientSearch: item.patientName, professionalId: item.professionalId,
      appointmentTypeId: item.appointmentTypeId, date: this.dateKey(new Date(item.start)), reason: item.reason, notes: item.notes ?? '' });
    this.modalOpen.set(true); this.clearMessages(); this.loadSlots();
  }

  closeModal(): void { if (!this.saving()) this.modalOpen.set(false); }

  searchPatients(query: string): void {
    this.form.controls.patientSearch.setValue(query); this.selectedPatient.set(null); this.selectedStart.set('');
    clearTimeout(this.patientSearchTimer);
    if (query.trim().length < 2) { this.patientResults.set([]); return; }
    this.patientSearchTimer = setTimeout(() => {
      this.searchingPatients.set(true);
      this.patientsApi.search({ q: query.trim(), active: true, page: 0, size: 8, sort: 'fullName', direction: 'asc' }).subscribe({
        next: (result) => { this.patientResults.set(result.content); this.searchingPatients.set(false); },
        error: () => { this.patientResults.set([]); this.searchingPatients.set(false); },
      });
    }, 250);
  }

  selectPatient(patient: PatientSummary): void {
    this.selectedPatient.set(patient); this.patientResults.set([]); this.form.controls.patientSearch.setValue(patient.fullName);
  }

  loadSlots(): void {
    const professionalId = this.form.controls.professionalId.value;
    const typeId = this.form.controls.appointmentTypeId.value; const date = this.form.controls.date.value;
    this.selectedStart.set(this.editing()?.start ?? ''); this.availability.set([]);
    if (!professionalId || !typeId || !date) return;
    this.loadingSlots.set(true);
    this.api.availability(professionalId, date, typeId).subscribe({
      next: (slots) => { this.availability.set(slots); this.loadingSlots.set(false); },
      error: () => { this.loadingSlots.set(false); this.error.set('No se pudo consultar la disponibilidad.'); },
    });
  }

  chooseSlot(slot: AvailabilitySlot): void { if (slot.available) this.selectedStart.set(slot.start); }

  save(): void {
    this.clearMessages(); const patient = this.selectedPatient();
    if (this.form.invalid || !patient || !this.selectedStart()) {
      this.form.markAllAsTouched(); this.error.set('Selecciona paciente, odontólogo, tipo, horario y motivo.'); return;
    }
    const value = this.form.getRawValue(); const editing = this.editing();
    const payload = { patientId: patient.id, professionalId: value.professionalId!, appointmentTypeId: value.appointmentTypeId!,
      start: this.selectedStart(), reason: value.reason.trim(), notes: value.notes.trim() || null, source: 'RECEPCION' as const };
    this.saving.set(true);
    const request = editing ? this.api.update(editing.id, { ...payload, version: editing.version }) : this.api.create(payload);
    request.subscribe({
      next: () => { this.saving.set(false); this.modalOpen.set(false); this.success.set(editing ? 'Cita reprogramada correctamente.' : 'Cita creada correctamente.'); this.load(); },
      error: (error: HttpErrorResponse) => { this.saving.set(false); this.error.set(error.error?.message || 'No se pudo guardar la cita.'); },
    });
  }

  advance(item: Appointment): void {
    const next = this.nextStatus(item.status); if (!next) return;
    this.updateStatus(item, next.status, undefined, next.success);
  }

  cancel(item: Appointment): void {
    const reason = window.prompt('Indica el motivo de cancelación:');
    if (!reason?.trim()) return;
    this.updateStatus(item, 'CANCELADA', reason.trim(), 'Cita cancelada.');
  }

  noShow(item: Appointment): void {
    if (!window.confirm(`¿Registrar que ${item.patientName} no asistió?`)) return;
    this.updateStatus(item, 'NO_ASISTIO', 'Paciente no asistió', 'Inasistencia registrada.');
  }

  nextActionLabel(status: AppointmentStatus): string {
    return ({ PENDIENTE_CONFIRMACION: 'Confirmar', CONFIRMADA: 'Registrar llegada', EN_ESPERA: 'Iniciar atención', EN_ATENCION: 'Completar' } as Partial<Record<AppointmentStatus, string>>)[status] ?? '';
  }

  statusLabel(status: AppointmentStatus): string { return status.replaceAll('_', ' ').toLowerCase(); }
  isToday(date: Date): boolean { return this.dateKey(date) === this.dateKey(new Date()); }
  trackAppointment(_: number, item: Appointment): number { return item.id; }

  private updateStatus(item: Appointment, status: AppointmentStatus, reason: string | undefined, success: string): void {
    this.saving.set(true); this.clearMessages();
    this.api.changeStatus(item.id, status, item.version, reason).subscribe({
      next: () => { this.saving.set(false); this.success.set(success); this.load(); },
      error: (error: HttpErrorResponse) => { this.saving.set(false); this.error.set(error.error?.message || 'No se pudo actualizar la cita.'); },
    });
  }

  private nextStatus(status: AppointmentStatus): { status: AppointmentStatus; success: string } | null {
    return ({ PENDIENTE_CONFIRMACION: { status: 'CONFIRMADA', success: 'Cita confirmada.' },
      CONFIRMADA: { status: 'EN_ESPERA', success: 'Llegada registrada.' },
      EN_ESPERA: { status: 'EN_ATENCION', success: 'Atención iniciada.' },
      EN_ATENCION: { status: 'COMPLETADA', success: 'Cita completada.' } } as Partial<Record<AppointmentStatus, { status: AppointmentStatus; success: string }>>)[status] ?? null;
  }
  private clearMessages(): void { this.error.set(''); this.success.set(''); }
  dateKey(date: Date): string { const y = date.getFullYear(); const m = String(date.getMonth() + 1).padStart(2, '0'); const d = String(date.getDate()).padStart(2, '0'); return `${y}-${m}-${d}`; }
  private parseDate(value: string): Date { const [year, month, day] = value.split('-').map(Number); return new Date(year, month - 1, day); }
}
