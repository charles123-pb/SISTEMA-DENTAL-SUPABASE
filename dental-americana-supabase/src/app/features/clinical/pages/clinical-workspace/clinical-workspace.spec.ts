import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { of, Subject } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { AppointmentApiService } from '../../../appointments/data-access/appointment-api.service';
import { Appointment } from '../../../appointments/models/appointment.models';
import { PatientApiService } from '../../../patients/data-access/patient-api.service';
import { ClinicalApiService } from '../../data-access/clinical-api.service';
import { ClinicalEncounter } from '../../models/clinical.models';
import { ClinicalWorkspace } from './clinical-workspace';

describe('Atención: continuidad y protección del paciente', () => {
  const encounter = { id: 3, patientId: 8, appointmentId: 42, status: 'BORRADOR', version: 1 } as ClinicalEncounter;
  let page: ClinicalWorkspace;
  let context: Record<string, string>;
  let start: ReturnType<typeof vi.fn>;
  let get: ReturnType<typeof vi.fn>;
  let getAppointment: ReturnType<typeof vi.fn>;
  let response: Subject<ClinicalEncounter>;

  beforeEach(() => {
    context = {};
    response = new Subject();
    start = vi.fn(() => response.asObservable());
    get = vi.fn(() => of(encounter));
    getAppointment = vi.fn(() => of({ id: 42, patientId: 8 } as Appointment));
    TestBed.configureTestingModule({ providers: [
      { provide: ActivatedRoute, useValue: { get snapshot() { return { queryParamMap: convertToParamMap(context) }; } } },
      { provide: AuthService, useValue: { hasPermission: () => true } },
      { provide: ClinicalApiService, useValue: { get, start, search: () => of([]) } },
      { provide: AppointmentApiService, useValue: { get: getAppointment, list: () => of([]) } },
      { provide: PatientApiService, useValue: { get: () => of({ id: 8, allergies: [] }) } },
    ] });
    page = TestBed.runInInjectionContext(() => new ClinicalWorkspace());
  });
  afterEach(() => vi.restoreAllMocks());

  it('retoma la atención exacta al volver desde odontograma, tratamiento o caja', () => {
    context = { encounterId: '3', appointmentId: '42' };
    page.ngOnInit();
    expect(get).toHaveBeenCalledWith(3);
    expect(page.current()?.id).toBe(3);
    expect(start).not.toHaveBeenCalled();
    expect(getAppointment).not.toHaveBeenCalled();
  });
  it('abre la cita enviada por Mi jornada', () => {
    context = { appointmentId: '42' };
    page.ngOnInit();
    expect(getAppointment).toHaveBeenCalledWith(42);
    expect(start).toHaveBeenCalledWith(8, 42);
    response.next(encounter);
    expect(page.current()?.appointmentId).toBe(42);
  });
  it('no pierde un borrador al cancelar el cambio de paciente', () => {
    page.open(encounter);
    page.form.controls.diagnosis.setValue('Texto pendiente');
    page.form.markAsDirty();
    vi.spyOn(window, 'confirm').mockReturnValue(false);
    page.open({ ...encounter, id: 4, patientId: 9 });
    page.close();
    page.openAppointment({ id: 43, patientId: 9 } as Appointment);
    expect(page.current()?.id).toBe(3);
    expect(page.form.controls.diagnosis.value).toBe('Texto pendiente');
    expect(start).not.toHaveBeenCalled();
  });
  it('bloquea el cierre mientras el servidor procesa la atención', () => {
    page.open(encounter);
    page.saving.set(true);
    page.close();
    expect(page.current()?.id).toBe(3);
  });
  it('no reinicia la ficha al pulsar otra vez la cita actual', () => {
    page.open(encounter);
    page.form.controls.diagnosis.setValue('Texto pendiente');
    page.form.markAsDirty();
    page.openAppointment({ id: 42, patientId: 8 } as Appointment);
    expect(page.form.controls.diagnosis.value).toBe('Texto pendiente');
    expect(start).not.toHaveBeenCalled();
  });
});
