-- Endurece la cola de WhatsApp para impedir envíos concurrentes duplicados.

alter table public.mensajes_whatsapp
  drop constraint if exists chk_mensaje_estado;

alter table public.mensajes_whatsapp
  add constraint chk_mensaje_estado check (estado in (
    'PENDIENTE', 'EN_PROCESO', 'ENVIADO', 'ENTREGADO', 'LEIDO',
    'RECIBIDO', 'FALLIDO', 'CANCELADO'
  ));

alter table public.mensajes_whatsapp
  add constraint chk_mensaje_contenido_whatsapp
  check (char_length(btrim(contenido)) between 1 and 4000) not valid;

do $$
begin
  if not exists (
    select 1 from public.mensajes_whatsapp
    where char_length(btrim(contenido)) not between 1 and 4000
  ) then
    alter table public.mensajes_whatsapp
      validate constraint chk_mensaje_contenido_whatsapp;
  end if;
end;
$$;

create index if not exists idx_mensaje_whatsapp_despacho
  on public.mensajes_whatsapp(programado_para, id)
  where estado = 'PENDIENTE';

create index if not exists idx_mensaje_whatsapp_en_proceso
  on public.mensajes_whatsapp(ultimo_intento_en)
  where estado = 'EN_PROCESO';
