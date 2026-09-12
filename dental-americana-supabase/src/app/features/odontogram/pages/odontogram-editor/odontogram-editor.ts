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
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  LucideAlertTriangle,
  LucideArrowLeft,
  LucideBaby,
  LucideCheck,
  LucideClipboardCheck,
  LucideHistory,
  LucideLoaderCircle,
  LucideMousePointerClick,
  LucidePalette,
  LucidePlus,
  LucideSave,
  LucideShieldCheck,
  LucideStethoscope,
  LucideTrash2,
} from '@lucide/angular';
import { Observable } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { SupabaseErrorService } from '../../../../core/supabase/supabase-error.service';
import { ClinicalApiService } from '../../../clinical/data-access/clinical-api.service';
import { ClinicalEncounter } from '../../../clinical/models/clinical.models';
import { OdontogramApiService } from '../../data-access/odontogram-api.service';
import {
  DentitionType,
  Odontogram,
  OdontogramFinding,
  ToothCondition,
  ToothSurface,
  TreatmentState,
} from '../../models/odontogram.models';
@Component({
  selector: 'app-odontogram-editor',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    DatePipe,
    LucideAlertTriangle,
    LucideArrowLeft,
    LucideBaby,
    LucideCheck,
    LucideClipboardCheck,
    LucideHistory,
    LucideLoaderCircle,
    LucideMousePointerClick,
    LucidePalette,
    LucidePlus,
    LucideSave,
    LucideShieldCheck,
    LucideStethoscope,
    LucideTrash2,
  ],
  templateUrl: './odontogram-editor.html',
  styleUrl: './odontogram-editor.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OdontogramEditor implements OnInit {
  private readonly fb = inject(FormBuilder).nonNullable;
  private readonly api = inject(OdontogramApiService);
  private readonly clinical = inject(ClinicalApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly errors = inject(SupabaseErrorService);
  readonly encounter = signal<ClinicalEncounter | null>(null);
  readonly items = signal<Odontogram[]>([]);
  readonly current = signal<Odontogram | null>(null);
  readonly dentition = signal<DentitionType>('PERMANENTE');
  readonly selectedTooth = signal('11');
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly quickMark = signal(true);
  readonly error = signal('');
  readonly success = signal('');
  readonly canWrite = signal(this.auth.hasPermission('CLINICA_ESCRIBIR'));
  readonly canApprove = signal(this.auth.hasPermission('CLINICA_APROBAR'));
  readonly permanentUpper = [
    '18',
    '17',
    '16',
    '15',
    '14',
    '13',
    '12',
    '11',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
  ];
  readonly permanentLower = [
    '48',
    '47',
    '46',
    '45',
    '44',
    '43',
    '42',
    '41',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
  ];
  readonly primaryUpper = ['55', '54', '53', '52', '51', '61', '62', '63', '64', '65'];
  readonly primaryLower = ['85', '84', '83', '82', '81', '71', '72', '73', '74', '75'];
  readonly upper = computed(() =>
    this.dentition() === 'PERMANENTE' ? this.permanentUpper : this.primaryUpper,
  );
  readonly lower = computed(() =>
    this.dentition() === 'PERMANENTE' ? this.permanentLower : this.primaryLower,
  );
  readonly selectedFindings = computed(
    () => this.current()?.findings.filter((f) => f.tooth === this.selectedTooth()) ?? [],
  );
  readonly clinicalSummary = computed(() => {
    const findings = this.current()?.findings ?? [];
    const toothCount = (predicate: (finding: OdontogramFinding) => boolean) =>
      new Set(findings.filter(predicate).map((finding) => finding.tooth)).size;

    return {
      findings: findings.length,
      caries: toothCount((finding) => finding.condition === 'CARIES'),
      indicated: toothCount((finding) => finding.treatmentState === 'INDICADO'),
      completed: toothCount((finding) => finding.treatmentState === 'REALIZADO'),
      absent: toothCount((finding) => finding.condition === 'AUSENTE'),
    };
  });
  readonly conditionOptions: ReadonlyArray<{
    value: ToothCondition;
    label: string;
    color: string;
  }> = [
    { value: 'CARIES', label: 'Caries', color: '#ef4444' },
    { value: 'RESTAURACION', label: 'Restauración', color: '#3b82f6' },
    { value: 'CORONA', label: 'Corona', color: '#8b5cf6' },
    { value: 'AUSENTE', label: 'Ausente', color: '#64748b' },
    { value: 'EXTRACCION_INDICADA', label: 'Extracción', color: '#f97316' },
    { value: 'ENDODONCIA', label: 'Endodoncia', color: '#a855f7' },
    { value: 'FRACTURA', label: 'Fractura', color: '#e11d48' },
    { value: 'SELLANTE', label: 'Sellante', color: '#06b6d4' },
    { value: 'PROTESIS', label: 'Prótesis', color: '#7c3aed' },
    { value: 'IMPLANTE', label: 'Implante', color: '#475569' },
    { value: 'MOVILIDAD', label: 'Movilidad', color: '#eab308' },
    { value: 'OTRO', label: 'Otro', color: '#0f766e' },
  ];
  readonly form = this.fb.group({
    surface: this.fb.control<ToothSurface>('GENERAL'),
    condition: this.fb.control<ToothCondition>('CARIES'),
    treatmentState: this.fb.control<TreatmentState>('INDICADO'),
    observation: ['', Validators.maxLength(500)],
  });
  readonly observation = this.fb.control('', Validators.maxLength(4000));
  ngOnInit(): void {
    const id = Number(this.route.snapshot.paramMap.get('encounterId'));
    if (!id) {
      void this.router.navigate(['/sistema/atencion']);
      return;
    }
    this.loading.set(true);
    this.clinical
      .get(id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (e) => {
          this.encounter.set(e);
          this.load(id);
        },
        error: (error: unknown) => {
          this.loading.set(false);
          this.error.set(this.errors.toUserMessage(error, 'No se encontró la atención clínica.'));
        },
      });
  }
  switchDentition(type: DentitionType): void {
    this.dentition.set(type);
    this.selectedTooth.set(type === 'PERMANENTE' ? '11' : '51');
    const existing = this.items().find((i) => i.dentitionType === type);
    if (existing) {
      this.setCurrent(existing);
    } else if (this.canWrite() && this.encounter()?.status === 'BORRADOR') {
      this.initialize(type);
    } else {
      this.current.set(null);
    }
  }
  selectTooth(tooth: string): void {
    this.selectedTooth.set(tooth);
    this.form.controls.surface.setValue('GENERAL');
    this.form.controls.observation.setValue('');
    this.clear();
  }
  findingsFor(tooth: string): OdontogramFinding[] {
    return this.current()?.findings.filter((f) => f.tooth === tooth) ?? [];
  }
  colorFor(tooth: string): string {
    const findings = this.findingsFor(tooth);
    if (
      findings.some(
        (f) =>
          f.treatmentState === 'INDICADO' ||
          ['CARIES', 'EXTRACCION_INDICADA', 'FRACTURA', 'MOVILIDAD'].includes(f.condition),
      )
    )
      return '#d35b64';
    if (findings.length) return '#3d81bc';
    return '#d5e0e6';
  }
  conditionColor(condition: ToothCondition): string {
    return this.conditionOptions.find((option) => option.value === condition)?.color ?? '#0f766e';
  }
  surfaceColor(tooth: string, surface: ToothSurface): string {
    const finding = [...this.findingsFor(tooth)]
      .reverse()
      .find((item) => item.surface === surface || item.surface === 'GENERAL');
    return finding ? this.conditionColor(finding.condition) : '#f8fafc';
  }
  hasSurfaceFinding(tooth: string, surface: ToothSurface): boolean {
    return this.findingsFor(tooth).some(
      (finding) => finding.surface === surface || finding.surface === 'GENERAL',
    );
  }
  isAbsent(tooth: string): boolean {
    return this.findingsFor(tooth).some((finding) => finding.condition === 'AUSENTE');
  }
  lateralSurface(tooth: string, side: 'left' | 'right'): ToothSurface {
    const mesialOnRight = ['1', '4', '5', '8'].includes(tooth[0]);
    return (side === 'right') === mesialOnRight ? 'MESIAL' : 'DISTAL';
  }
  verticalSurface(tooth: string, side: 'top' | 'bottom'): ToothSurface {
    const isUpper = ['1', '2', '5', '6'].includes(tooth[0]);
    return (side === 'top') === isUpper ? 'VESTIBULAR' : 'LINGUAL_PALATINA';
  }
  surfaceLabel(tooth: string, surface: ToothSurface): string {
    const resolved =
      surface === 'OCLUSAL' || surface === 'INCISAL' ? this.centerSurfaceFor(tooth) : surface;
    return `${this.label(resolved)} de la pieza ${tooth}`;
  }
  toothDescription(tooth: string): string {
    const quadrant: Record<string, string> = {
      '1': 'superior derecha, permanente',
      '2': 'superior izquierda, permanente',
      '3': 'inferior izquierda, permanente',
      '4': 'inferior derecha, permanente',
      '5': 'superior derecha, temporal',
      '6': 'superior izquierda, temporal',
      '7': 'inferior izquierda, temporal',
      '8': 'inferior derecha, temporal',
    };
    const permanent = [
      '',
      'incisivo central',
      'incisivo lateral',
      'canino',
      'primer premolar',
      'segundo premolar',
      'primer molar',
      'segundo molar',
      'tercer molar',
    ];
    const primary = [
      '',
      'incisivo central',
      'incisivo lateral',
      'canino',
      'primer molar',
      'segundo molar',
    ];
    const position = (Number(tooth[0]) <= 4 ? permanent : primary)[Number(tooth[1])] ?? 'pieza';
    return `Pieza ${tooth}: ${position}, arcada ${quadrant[tooth[0]] ?? 'no identificada'} (lado del paciente)`;
  }
  centerSurface(): ToothSurface {
    return this.centerSurfaceFor(this.selectedTooth());
  }
  centerSurfaceFor(tooth: string): ToothSurface {
    return Number(tooth[1]) <= 3 ? 'INCISAL' : 'OCLUSAL';
  }
  chooseSurface(surface: ToothSurface): void {
    this.form.controls.surface.setValue(surface);
  }
  chooseCondition(condition: ToothCondition): void {
    this.form.controls.condition.setValue(condition);
  }
  markSurface(tooth: string, surface: ToothSurface): void {
    if (this.saving()) return;
    this.selectedTooth.set(tooth);
    this.form.controls.surface.setValue(surface);
    this.clear();

    if (this.quickMark() && this.canWrite() && this.current()?.status === 'BORRADOR') {
      this.add(true);
    }
  }
  add(quick = false): void {
    const item = this.current();
    if (
      !item ||
      !this.canWrite() ||
      item.status !== 'BORRADOR' ||
      this.form.invalid ||
      this.saving()
    )
      return;
    const value = this.form.getRawValue();
    this.run(
      this.api.addFinding(item.id, {
        tooth: this.selectedTooth(),
        surface: value.surface,
        condition: value.condition,
        treatmentState: value.treatmentState,
        observation: value.observation.trim() || null,
        version: item.version,
      }),
      quick
        ? `Pieza ${this.selectedTooth()} marcada correctamente.`
        : 'Hallazgo confirmado y registrado.',
      () => this.form.controls.observation.setValue(''),
    );
  }
  remove(finding: OdontogramFinding): void {
    const item = this.current();
    if (
      !item ||
      !this.canWrite() ||
      item.status !== 'BORRADOR' ||
      this.saving() ||
      !window.confirm(`¿Retirar ${this.label(finding.condition)} de la pieza ${finding.tooth}?`)
    )
      return;
    this.run(
      this.api.removeFinding(item.id, finding.id, finding.version),
      'Hallazgo retirado.',
      () => {},
    );
  }
  saveObservation(): void {
    const item = this.current();
    if (
      !item ||
      !this.canWrite() ||
      item.status !== 'BORRADOR' ||
      this.observation.invalid ||
      this.saving()
    )
      return;
    this.run(
      this.api.observe(item.id, this.observation.value, item.version),
      'Observación general guardada.',
      () => {},
    );
  }
  approve(): void {
    const item = this.current();
    if (
      !item ||
      !this.canApprove() ||
      item.status !== 'BORRADOR' ||
      this.saving() ||
      !window.confirm(
        '¿Confirmas que revisaste todas las piezas y deseas aprobar este odontograma?',
      )
    )
      return;
    this.run(
      this.api.approve(item.id, item.version),
      'Odontograma aprobado por el profesional.',
      () => {},
    );
  }
  label(value: string): string {
    return value.replaceAll('_', ' ').toLowerCase();
  }
  private initialize(type: DentitionType): void {
    if (this.saving() || !this.canWrite() || this.encounter()?.status !== 'BORRADOR') return;
    this.saving.set(true);
    this.api
      .initialize(this.encounter()!.id, type)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (item) => {
          this.items.update((v) => [...v.filter((i) => i.dentitionType !== type), item]);
          this.setCurrent(item);
          this.saving.set(false);
        },
        error: (e) => this.fail(e, 'No se pudo crear el odontograma.'),
      });
  }
  private load(id: number): void {
    this.api
      .list(id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (items) => {
          this.items.set(items);
          const current = items.find((i) => i.dentitionType === this.dentition());
          if (current) this.setCurrent(current);
          else if (this.canWrite() && this.encounter()?.status === 'BORRADOR')
            this.initialize(this.dentition());
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.loading.set(false);
          this.error.set(this.errors.toUserMessage(error, 'No se pudo cargar el odontograma.'));
        },
      });
  }
  private setCurrent(item: Odontogram): void {
    this.current.set(item);
    this.observation.setValue(item.generalObservation ?? '');
    this.observation.markAsPristine();
  }
  private run(request: Observable<Odontogram>, message: string, done: () => void): void {
    if (this.saving()) return;
    this.saving.set(true);
    this.clear();
    request.pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: (item) => {
        this.items.update((v) => [
          ...v.filter((i) => i.dentitionType !== item.dentitionType),
          item,
        ]);
        this.setCurrent(item);
        this.saving.set(false);
        this.success.set(message);
        done();
      },
      error: (e) => this.fail(e, 'No se pudo guardar el cambio.'),
    });
  }
  private fail(e: unknown, fallback: string): void {
    this.saving.set(false);
    this.error.set(this.errors.toUserMessage(e, fallback));
  }
  private clear(): void {
    this.error.set('');
    this.success.set('');
  }
}
