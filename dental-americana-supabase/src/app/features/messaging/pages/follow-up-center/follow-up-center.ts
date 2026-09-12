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
import { RouterLink } from '@angular/router';
import {
  LucideAlertTriangle,
  LucideCalendar,
  LucideCheck,
  LucideCheckCheck,
  LucideClock3,
  LucideLoaderCircle,
  LucideMessageCircle,
  LucidePhone,
  LucidePlus,
  LucideRefreshCw,
  LucideRotateCcw,
  LucideSearch,
  LucideSend,
  LucideUser,
  LucideWifi,
  LucideWifiOff,
  LucideX,
} from '@lucide/angular';
import { finalize, forkJoin, interval } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { PatientApiService } from '../../../patients/data-access/patient-api.service';
import { PatientSummary } from '../../../patients/models/patient.models';
import { MessagingApiService } from '../../data-access/messaging-api.service';
import { Conversation, FollowUp, Message, WhatsAppSession } from '../../models/messaging.models';

type View = 'chat' | 'followups';
@Component({
  selector: 'app-follow-up-center',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    DatePipe,
    LucideAlertTriangle,
    LucideCalendar,
    LucideCheck,
    LucideCheckCheck,
    LucideClock3,
    LucideLoaderCircle,
    LucideMessageCircle,
    LucidePhone,
    LucidePlus,
    LucideRefreshCw,
    LucideRotateCcw,
    LucideSearch,
    LucideSend,
    LucideUser,
    LucideWifi,
    LucideWifiOff,
    LucideX,
  ],
  templateUrl: './follow-up-center.html',
  styleUrl: './follow-up-center.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class FollowUpCenter implements OnInit {
  private readonly fb = inject(FormBuilder).nonNullable;
  private readonly destroyRef = inject(DestroyRef);
  private readonly api = inject(MessagingApiService);
  private readonly patientApi = inject(PatientApiService);
  private readonly auth = inject(AuthService);
  readonly conversations = signal<Conversation[]>([]);
  readonly messages = signal<Message[]>([]);
  readonly followups = signal<FollowUp[]>([]);
  readonly selected = signal<Conversation | null>(null);
  readonly session = signal<WhatsAppSession>({ status: 'DESCONECTADO' });
  readonly loading = signal(true);
  readonly loadingMessages = signal(false);
  readonly saving = signal(false);
  readonly syncing = signal(false);
  readonly refreshing = signal(false);
  readonly error = signal('');
  readonly success = signal('');
  readonly view = signal<View>('chat');
  readonly connectionDialog = signal(false);
  readonly composeDialog = signal(false);
  readonly results = signal<PatientSummary[]>([]);
  readonly selectedPatient = signal<PatientSummary | null>(null);
  readonly canWrite = signal(this.auth.hasPermission('SEGUIMIENTO_ESCRIBIR'));
  readonly alerts = computed(() => this.followups().filter((item) => item.status === 'ALERTA'));
  private conversationSearchTimer?: ReturnType<typeof setTimeout>;
  private patientSearchTimer?: ReturnType<typeof setTimeout>;
  private qrRefreshTimer?: ReturnType<typeof setTimeout>;
  private refreshQueued = false;
  readonly searchForm = this.fb.group({ query: [''] });
  readonly messageForm = this.fb.group({
    content: ['', [Validators.required, Validators.maxLength(4000)]],
  });
  readonly composeForm = this.fb.group({ search: [''], content: ['', Validators.required] });

  ngOnInit() {
    this.destroyRef.onDestroy(() => {
      clearTimeout(this.conversationSearchTimer);
      clearTimeout(this.patientSearchTimer);
      clearTimeout(this.qrRefreshTimer);
    });
    this.loadAll();
    this.api
      .realtime()
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => {
        if (!this.syncing()) this.refreshQuietly();
      });
    interval(30000)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => {
        if (!document.hidden && !this.saving() && !this.syncing()) this.refreshQuietly();
      });
  }
  loadAll() {
    this.loading.set(true);
    this.error.set('');
    forkJoin({
      conversations: this.api.conversations(this.searchForm.controls.query.value),
      followups: this.api.followUps(),
      session: this.api.session(),
    }).subscribe({
      next: (data) => {
        this.conversations.set(data.conversations);
        this.followups.set(data.followups);
        this.applySessionState(data.session);
        this.reconcileSelection();
        this.loading.set(false);
        if (this.canWrite() && data.session.status === 'CONECTADO' && !data.conversations.length) {
          this.syncChats(false);
        }
      },
      error: (error) => {
        this.loading.set(false);
        this.error.set(error.message || 'No se pudo cargar WhatsApp.');
      },
    });
  }
  refreshQuietly() {
    if (this.refreshing()) {
      this.refreshQueued = true;
      return;
    }
    this.refreshing.set(true);
    forkJoin({
      conversations: this.api.conversations(this.searchForm.controls.query.value),
      session: this.api.session(),
    }).pipe(finalize(() => {
      this.refreshing.set(false);
      if (this.refreshQueued) {
        this.refreshQueued = false;
        this.refreshQuietly();
      }
    })).subscribe({
      next: ({ conversations, session }) => {
        this.conversations.set(conversations);
        this.applySessionState(session);
        this.reconcileSelection();
        const current = this.selected();
        if (current) this.loadMessages(current.id, false);
      },
    });
  }
  filterConversations() {
    clearTimeout(this.conversationSearchTimer);
    this.conversationSearchTimer = setTimeout(
      () =>
        this.api
          .conversations(this.searchForm.controls.query.value)
          .subscribe({ next: (items) => this.conversations.set(items) }),
      250,
    );
  }
  openConversation(conversation: Conversation) {
    this.selected.set(conversation);
    this.loadMessages(conversation.id, true);
    if (conversation.unreadCount)
      this.api.markRead(conversation.id).subscribe({
        next: () => {
          this.conversations.update((items) =>
            items.map((item) => (item.id === conversation.id ? { ...item, unreadCount: 0 } : item)),
          );
        },
      });
  }
  loadMessages(id: number, showLoader = true) {
    if (showLoader) this.loadingMessages.set(true);
    this.api.conversationMessages(id).subscribe({
      next: (items) => {
        this.messages.set(items);
        this.loadingMessages.set(false);
      },
      error: (error) => {
        this.loadingMessages.set(false);
        this.error.set(error.message);
      },
    });
  }
  send() {
    const conversation = this.selected();
    const content = this.messageForm.controls.content.value.trim();
    if (!conversation?.patientId || !content || this.messageForm.invalid) return;
    this.saving.set(true);
    this.error.set('');
    this.api.send(conversation.patientId, content).subscribe({
      next: () => {
        this.saving.set(false);
        this.messageForm.reset();
        this.loadMessages(conversation.id);
      },
      error: (error) => {
        this.saving.set(false);
        this.error.set(error.message || 'No se pudo enviar.');
      },
    });
  }
  handleEnter(event: Event) {
    const keyboardEvent = event as KeyboardEvent;
    if (keyboardEvent.shiftKey) return;
    keyboardEvent.preventDefault();
    this.send();
  }
  retry(message: Message) {
    this.saving.set(true);
    this.api.retry(message.id).subscribe({
      next: () => {
        this.saving.set(false);
        if (this.selected()) this.loadMessages(this.selected()!.id);
      },
      error: (error) => {
        this.saving.set(false);
        this.error.set(error.message);
      },
    });
  }
  connect() {
    if (!this.canWrite()) return;
    this.saving.set(true);
    this.session.update((current) => ({ ...current, status: 'CONECTANDO', detail: undefined }));
    this.api.connect().subscribe({
      next: (state) => {
        this.saving.set(false);
        this.session.set(state);
        this.connectionDialog.set(true);
        if (state.qrCode || state.pairingCode) this.scheduleQrRefresh();
      },
      error: (error) => {
        this.saving.set(false);
        this.session.set({ status: 'ERROR', detail: error.message });
        this.error.set(error.message);
      },
    });
  }
  syncChats(showMessage = true) {
    if (this.syncing()) return;
    this.syncing.set(true);
    this.error.set('');
    this.api.sync().subscribe({
      next: (result) => {
        this.api.conversations(this.searchForm.controls.query.value).subscribe({
          next: (items) => {
            this.conversations.set(items);
            this.reconcileSelection();
            this.syncing.set(false);
            if (showMessage)
              this.success.set(
                `WhatsApp sincronizado: ${result.chats} chats y ${result.messages} mensajes revisados.`,
              );
          },
          error: (error) => {
            this.syncing.set(false);
            this.error.set(error.message || 'No se pudieron cargar las conversaciones sincronizadas.');
          },
        });
      },
      error: (error) => {
        this.syncing.set(false);
        this.error.set(error.message || 'No se pudo sincronizar el historial de WhatsApp.');
      },
    });
  }
  searchPatients(query: string) {
    clearTimeout(this.patientSearchTimer);
    this.selectedPatient.set(null);
    if (query.trim().length < 2) {
      this.results.set([]);
      return;
    }
    this.patientSearchTimer = setTimeout(
      () =>
        this.patientApi
          .search({ q: query.trim(), active: true, page: 0, size: 8 })
          .subscribe((result) => this.results.set(result.content)),
      250,
    );
  }
  selectPatient(patient: PatientSummary) {
    if (!patient.mobile || !patient.whatsappConsent) {
      this.error.set(
        !patient.mobile ? 'El paciente no tiene celular.' : 'El paciente no autorizó WhatsApp.',
      );
      return;
    }
    this.selectedPatient.set(patient);
    this.results.set([]);
    this.composeForm.controls.search.setValue(patient.fullName);
  }
  sendNew() {
    const patient = this.selectedPatient();
    const content = this.composeForm.controls.content.value.trim();
    if (!patient || !content) return;
    this.saving.set(true);
    this.api.send(patient.id, content).subscribe({
      next: () => {
        this.saving.set(false);
        this.composeDialog.set(false);
        this.composeForm.reset();
        this.selectedPatient.set(null);
        this.loadAll();
      },
      error: (error) => {
        this.saving.set(false);
        this.error.set(error.message);
      },
    });
  }
  review(followup: FollowUp) {
    if (!confirm('¿Confirmas que revisaste profesionalmente esta respuesta?')) return;
    this.api
      .review(followup.id, followup.version)
      .subscribe({ next: () => this.loadAll(), error: (e) => this.error.set(e.message) });
  }
  statusLabel(value: string) {
    return value.replaceAll('_', ' ').toLowerCase();
  }
  initials(name: string) {
    return name
      .split(' ')
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase();
  }
  trackMessage(_index: number, message: Message) {
    return message.id;
  }
  private applySessionState(state: WhatsAppSession) {
    const current = this.session();
    if (state.status === 'CONECTADO') clearTimeout(this.qrRefreshTimer);
    if (
      this.connectionDialog() &&
      current.qrCode &&
      state.status === 'CONECTANDO' &&
      !state.qrCode
    ) {
      this.session.set({
        ...state,
        qrCode: current.qrCode,
        pairingCode: current.pairingCode,
        code: current.code,
      });
      return;
    }
    this.session.set(state);
  }
  private scheduleQrRefresh() {
    clearTimeout(this.qrRefreshTimer);
    this.qrRefreshTimer = setTimeout(() => {
      if (
        this.connectionDialog() &&
        this.session().status === 'CONECTANDO' &&
        !this.saving()
      ) {
        this.connect();
      }
    }, 25_000);
  }
  private reconcileSelection() {
    const current = this.selected();
    if (!current) return;
    const updated = this.conversations().find((item) => item.id === current.id);
    if (updated) this.selected.set(updated);
  }
}
