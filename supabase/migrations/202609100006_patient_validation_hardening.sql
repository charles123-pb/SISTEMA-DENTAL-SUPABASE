-- Reglas de identidad del paciente aplicadas en base de datos, no solo en Angular.

alter table public.pacientes
  add constraint chk_paciente_tipo_documento_valido
  check (tipo_documento in ('DNI', 'CE', 'PASAPORTE', 'SIN_DOCUMENTO')) not valid,
  add constraint chk_paciente_sexo_valido
  check (sexo in ('FEMENINO', 'MASCULINO', 'OTRO', 'NO_ESPECIFICA')) not valid,
  add constraint chk_paciente_nombres_no_vacios
  check (char_length(btrim(nombres)) between 2 and 100
    and char_length(btrim(apellido_paterno)) between 2 and 80) not valid;

create or replace function public.validar_datos_paciente(datos jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  tipo text;
  documento text;
  nacimiento date;
  celular text;
  telefono text;
  correo text;
  consentimiento boolean;
  nombres text;
  apellido text;
  sexo_value text;
begin
  if datos is null or jsonb_typeof(datos) <> 'object' then
    raise exception using errcode = 'P0001', message = 'Los datos del paciente no son válidos';
  end if;

  tipo := datos ->> 'documentType';
  documento := nullif(upper(btrim(coalesce(datos ->> 'documentNumber', ''))), '');
  nombres := regexp_replace(btrim(coalesce(datos ->> 'firstNames', '')), '\s+', ' ', 'g');
  apellido := regexp_replace(btrim(coalesce(datos ->> 'paternalSurname', '')), '\s+', ' ', 'g');
  sexo_value := datos ->> 'sex';
  celular := nullif(public.normalizar_telefono_whatsapp(datos ->> 'mobile'), '');
  telefono := nullif(regexp_replace(coalesce(datos ->> 'phone', ''), '[^0-9]', '', 'g'), '');
  correo := nullif(lower(btrim(coalesce(datos ->> 'email', ''))), '');

  if coalesce(datos ->> 'whatsappConsent', 'false') not in ('true', 'false') then
    raise exception using errcode = 'P0001', message = 'La autorización de WhatsApp no es válida';
  end if;
  consentimiento := coalesce(datos ->> 'whatsappConsent', 'false') = 'true';

  if tipo not in ('DNI', 'CE', 'PASAPORTE', 'SIN_DOCUMENTO') then
    raise exception using errcode = 'P0001', message = 'Tipo de documento inválido';
  end if;
  if char_length(nombres) not between 2 and 100 then
    raise exception using errcode = 'P0001', message = 'Ingrese los nombres del paciente';
  end if;
  if char_length(apellido) not between 2 and 80 then
    raise exception using errcode = 'P0001', message = 'Ingrese el apellido paterno del paciente';
  end if;
  if sexo_value not in ('FEMENINO', 'MASCULINO', 'OTRO', 'NO_ESPECIFICA') then
    raise exception using errcode = 'P0001', message = 'Sexo del paciente inválido';
  end if;
  if tipo = 'SIN_DOCUMENTO' and documento is not null then
    raise exception using errcode = 'P0001', message = 'SIN_DOCUMENTO no debe incluir número';
  end if;
  if tipo <> 'SIN_DOCUMENTO' and documento is null then
    raise exception using errcode = 'P0001', message = 'El número de documento es obligatorio';
  end if;
  if tipo = 'DNI' and coalesce(documento, '') !~ '^[0-9]{8}$' then
    raise exception using errcode = 'P0001', message = 'El DNI debe tener ocho dígitos';
  end if;
  if documento is not null and char_length(documento) > 20 then
    raise exception using errcode = 'P0001', message = 'El documento supera la longitud permitida';
  end if;

  begin
    nacimiento := nullif(datos ->> 'birthDate', '')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception using errcode = 'P0001', message = 'La fecha de nacimiento no es válida';
  end;
  if nacimiento is null then
    raise exception using errcode = 'P0001', message = 'La fecha de nacimiento es obligatoria';
  end if;
  if nacimiento > current_date then
    raise exception using errcode = 'P0001', message = 'La fecha de nacimiento no puede ser futura';
  end if;
  if nacimiento < current_date - interval '130 years' then
    raise exception using errcode = 'P0001', message = 'Revise la fecha de nacimiento';
  end if;

  if celular is not null and celular !~ '^[0-9]{10,15}$' then
    raise exception using errcode = 'P0001', message = 'El celular no es válido';
  end if;
  if telefono is not null and char_length(telefono) not between 6 and 15 then
    raise exception using errcode = 'P0001', message = 'El teléfono no es válido';
  end if;
  if correo is not null and (
    char_length(correo) > 150 or correo !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ) then
    raise exception using errcode = 'P0001', message = 'El correo electrónico no es válido';
  end if;

  if extract(year from age(current_date, nacimiento)) < 18 and
    (nullif(btrim(datos ->> 'responsibleName'), '') is null
     or nullif(btrim(datos ->> 'responsibleRelationship'), '') is null
     or nullif(regexp_replace(coalesce(datos ->> 'responsiblePhone', ''), '[^0-9]', '', 'g'), '') is null) then
    raise exception using errcode = 'P0001', message = 'Los menores de edad requieren responsable, parentesco y teléfono';
  end if;
  if consentimiento and celular is null then
    raise exception using errcode = 'P0001', message = 'Registre un celular antes de autorizar WhatsApp';
  end if;
end;
$$;

revoke all on function public.validar_datos_paciente(jsonb) from public, anon, authenticated;
