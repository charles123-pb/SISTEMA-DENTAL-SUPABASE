import { CurrencyPipe, DatePipe } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  OnInit,
  inject,
  signal,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  LucideAlertTriangle,
  LucideArrowLeft,
  LucideCheck,
  LucideClipboardCheck,
  LucideFileText,
  LucideLoaderCircle,
  LucidePlus,
  LucideSave,
  LucideSparkles,
  LucideTrash2,
} from '@lucide/angular';
import { forkJoin, Observable } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { SupabaseErrorService } from '../../../../core/supabase/supabase-error.service';
import { ClinicalApiService } from '../../../clinical/data-access/clinical-api.service';
import { ClinicalEncounter } from '../../../clinical/models/clinical.models';
import { TreatmentApiService } from '../../data-access/treatment-api.service';
import {
  DentalService,
  ItemStatus,
  PlanStatus,
  TreatmentItem,
  TreatmentPlan,
} from '../../models/treatment.models';
@Component({
  selector: 'app-treatment-plan',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    CurrencyPipe,
    DatePipe,
    LucideAlertTriangle,
    LucideArrowLeft,
    LucideCheck,
    LucideClipboardCheck,
    LucideFileText,
    LucideLoaderCircle,
    LucidePlus,
    LucideSave,
    LucideSparkles,
    LucideTrash2,
  ],
  templateUrl: './treatment-plan.html',
  styleUrl: './treatment-plan.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TreatmentPlanPage implements OnInit {
  private readonly fb = inject(FormBuilder).nonNullable;
  private readonly api = inject(TreatmentApiService);
  private readonly clinical = inject(ClinicalApiService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly errors = inject(SupabaseErrorService);
  readonly encounter = signal<ClinicalEncounter | null>(null);
  readonly plan = signal<TreatmentPlan | null>(null);
  readonly services = signal<DentalService[]>([]);
  readonly loading = signal(true);
  readonly saving = signal(false);
  readonly error = signal('');
  readonly success = signal('');
  readonly addOpen = signal(false);
  readonly selectedItem = signal<TreatmentItem | null>(null);
  readonly acceptance = signal(false);
  readonly canWrite = signal(this.auth.hasPermission('TRATAMIENTO_ESCRIBIR'));
  readonly itemForm = this.fb.group({
    serviceId: this.fb.control<number | null>(null, Validators.required),
    tooth: ['', Validators.maxLength(3)],
    description: ['', Validators.maxLength(500)],
    quantity: [1, [Validators.min(1), Validators.max(99)]],
    unitPrice: [0, Validators.min(0)],
    sessions: [1, [Validators.min(1), Validators.max(50)]],
  });
  readonly planForm = this.fb.group({
    discount: [0, Validators.min(0)],
    observations: ['', Validators.maxLength(1000)],
  });
  readonly evolutionForm = this.fb.group({
    procedure: ['', [Validators.required, Validators.maxLength(4000)]],
    observations: ['', Validators.maxLength(4000)],
    nextSession: [''],
  });
  ngOnInit(): void {
    const id = Number(this.route.snapshot.paramMap.get('encounterId'));
    if (!id) {
      void this.router.navigate(['/sistema/atencion']);
      return;
    }
    forkJoin({
      encounter: this.clinical.get(id),
      services: this.api.catalog(),
      plans: this.api.listByEncounter(id),
    })
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (r) => {
          this.encounter.set(r.encounter);
          this.services.set(r.services);
          if (r.plans[0]) this.setPlan(r.plans[0]);
          this.loading.set(false);
        },
        error: (error: unknown) => {
          this.loading.set(false);
          this.error.set(
            this.errors.toUserMessage(error, 'No se pudo cargar el plan de tratamiento.'),
          );
        },
      });
  }
  create(): void {
    const e = this.encounter();
    if (!e || !this.canWrite() || this.saving()) return;
    this.run(this.api.create(e.patientId, e.id), 'Plan de tratamiento creado.');
  }
  selectService(value: string): void {
    const s = this.services().find((x) => x.id === Number(value));
    if (!s) return;
    this.itemForm.patchValue({
      serviceId: s.id,
      description: s.name,
      unitPrice: s.basePrice,
      sessions: s.suggestedSessions,
    });
  }
  addItem(): void {
    const p = this.plan();
    if (
      !p ||
      !this.canWrite() ||
      p.status !== 'BORRADOR' ||
      this.itemForm.invalid ||
      this.saving()
    ) {
      this.itemForm.markAllAsTouched();
      return;
    }
    const v = this.itemForm.getRawValue();
    this.run(
      this.api.addItem(p.id, {
        serviceId: v.serviceId!,
        tooth: v.tooth.trim() || null,
        description: v.description.trim() || null,
        quantity: v.quantity,
        unitPrice: v.unitPrice,
        sessions: v.sessions,
      }),
      'Procedimiento agregado.',
      () => {
        this.addOpen.set(false);
        this.itemForm.reset({
          serviceId: null,
          tooth: '',
          description: '',
          quantity: 1,
          unitPrice: 0,
          sessions: 1,
        });
      },
    );
  }
  remove(item: TreatmentItem): void {
    const p = this.plan();
    if (
      !p ||
      !this.canWrite() ||
      p.status !== 'BORRADOR' ||
      this.saving() ||
      !confirm(`¿Retirar ${item.serviceName} del presupuesto?`)
    )
      return;
    this.run(this.api.removeItem(p.id, item.id, item.version), 'Procedimiento retirado.');
  }
  savePlan(): void {
    const p = this.plan();
    if (
      !p ||
      !this.canWrite() ||
      p.status !== 'BORRADOR' ||
      this.planForm.invalid ||
      this.saving()
    ) {
      this.planForm.markAllAsTouched();
      return;
    }
    const v = this.planForm.getRawValue();
    this.run(
      this.api.revise(p.id, v.discount, v.observations.trim() || null, p.version),
      'Presupuesto actualizado.',
    );
  }
  changeStatus(status: PlanStatus): void {
    const p = this.plan();
    if (!p || !this.canWrite() || this.saving()) return;
    if (status === 'ACEPTADO' && !this.acceptance()) {
      this.error.set('Registra la aceptación expresa del paciente.');
      return;
    }
    this.run(
      this.api.status(p.id, status, this.acceptance(), p.version),
      `Plan ${status.replaceAll('_', ' ').toLowerCase()}.`,
    );
  }
  openEvolution(item: TreatmentItem): void {
    const p = this.plan();
    if (
      !p ||
      !this.canWrite() ||
      !['ACEPTADO', 'EN_PROCESO'].includes(p.status) ||
      ['COMPLETADO', 'CANCELADO'].includes(item.status)
    )
      return;
    this.selectedItem.set(item);
    this.evolutionForm.reset({ procedure: '', observations: '', nextSession: '' });
  }
  saveEvolution(): void {
    const p = this.plan(),
      item = this.selectedItem(),
      e = this.encounter();
    if (!p || !item || !e || !this.canWrite() || this.saving() || this.evolutionForm.invalid) {
      this.evolutionForm.markAllAsTouched();
      return;
    }
    const v = this.evolutionForm.getRawValue();
    this.run(
      this.api.evolution(p.id, item.id, {
        encounterId: e.id,
        procedure: v.procedure.trim(),
        observations: v.observations.trim() || null,
        nextSession: v.nextSession || null,
      }),
      'Evolución aprobada y registrada.',
      () => this.selectedItem.set(null),
    );
  }
  completeItem(item: TreatmentItem): void {
    const p = this.plan();
    if (
      !p ||
      !this.canWrite() ||
      this.saving() ||
      item.status !== 'EN_PROCESO' ||
      !item.evolutions.length
    )
      return;
    this.run(
      this.api.itemStatus(p.id, item.id, 'COMPLETADO', item.version),
      'Procedimiento completado.',
    );
  }
  label(v: string): string {
    return v.replaceAll('_', ' ').toLowerCase();
  }
  private setPlan(p: TreatmentPlan): void {
    this.plan.set(p);
    this.planForm.reset({ discount: p.discount, observations: p.observations ?? '' });
    this.planForm.markAsPristine();
  }
  private run(
    request: Observable<TreatmentPlan>,
    message: string,
    done: () => void = () => {},
  ): void {
    if (this.saving()) return;
    this.saving.set(true);
    this.error.set('');
    this.success.set('');
    request.pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: (p) => {
        this.setPlan(p);
        this.saving.set(false);
        this.success.set(message);
        done();
      },
      error: (e: unknown) => {
        this.saving.set(false);
        this.error.set(this.errors.toUserMessage(e, 'No se pudo guardar el cambio.'));
      },
    });
  }
}
