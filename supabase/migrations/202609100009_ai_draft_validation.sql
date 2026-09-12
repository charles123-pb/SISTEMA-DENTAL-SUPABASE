-- Valida los borradores de DENTALIA incluso si el RPC se invoca fuera de Angular.

create or replace function public.validar_borrador_ia()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.contenido := btrim(new.contenido);
  if new.contenido = '' then
    raise exception using errcode = 'P0001', message = 'El borrador no puede estar vacío';
  end if;
  if char_length(new.contenido) > 20000 then
    raise exception using errcode = 'P0001', message = 'El borrador supera los 20 000 caracteres';
  end if;
  if jsonb_typeof(new.datos_fuente) <> 'object' or jsonb_typeof(new.campos_faltantes) <> 'array' then
    raise exception using errcode = 'P0001', message = 'Los datos de trazabilidad del borrador son inválidos';
  end if;
  if char_length(coalesce(new.motivo_rechazo, '')) > 500 then
    raise exception using errcode = 'P0001', message = 'El motivo del rechazo supera los 500 caracteres';
  end if;
  if new.estado in ('APROBADO', 'RECHAZADO') and (new.revisado_por is null or new.revisado_en is null) then
    raise exception using errcode = 'P0001', message = 'El borrador revisado requiere responsable y fecha';
  end if;
  if new.estado = 'RECHAZADO' and nullif(btrim(new.motivo_rechazo), '') is null then
    raise exception using errcode = 'P0001', message = 'Indique el motivo del rechazo';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_borrador_ia_trigger on public.borradores_ia;
create trigger validar_borrador_ia_trigger
before insert or update on public.borradores_ia
for each row execute function public.validar_borrador_ia();

revoke all on function public.validar_borrador_ia() from public;
