#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
env_file="${project_dir}/.env"

if [[ ! -f "${env_file}" ]]; then
  printf 'Falta %s. Copie .env.example a .env antes de continuar.\n' "${env_file}" >&2
  exit 1
fi

set_env() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file="$(mktemp "${project_dir}/.env.whatsapp.XXXXXX")"
  awk -v key="${key}" -v value="${value}" '
    BEGIN { updated = 0 }
    index($0, key "=") == 1 { print key "=" value; updated = 1; next }
    { print }
    END { if (!updated) print key "=" value }
  ' "${env_file}" > "${tmp_file}"
  chmod --reference="${env_file}" "${tmp_file}"
  mv "${tmp_file}" "${env_file}"
}

if [[ "${1:-}" == "--reset" ]]; then
  set_env WHATSAPP_ENABLED false
  set_env WHATSAPP_GRAPH_BASE_URL https://graph.facebook.com/v25.0
  set_env WHATSAPP_PHONE_NUMBER_ID ""
  set_env WHATSAPP_ACCESS_TOKEN ""
  set_env WHATSAPP_APP_SECRET ""
  set_env WHATSAPP_WEBHOOK_VERIFY_TOKEN ""
  set_env WHATSAPP_TEMPLATE_APPOINTMENT_CONFIRMATION ""
  set_env WHATSAPP_TEMPLATE_APPOINTMENT_REMINDER ""
  set_env WHATSAPP_TEMPLATE_FOLLOW_UP ""
  printf 'Configuración local de WhatsApp restablecida. Los datos clínicos no fueron modificados.\n'
  exit 0
fi

printf 'Configuración segura de WhatsApp Cloud API para pruebas.\n'
printf 'Los secretos se leen ocultos y no se imprimen.\n\n'

default_phone_id="1306952745836473"
read -r -p "Phone Number ID [${default_phone_id}]: " phone_id
phone_id="${phone_id:-${default_phone_id}}"
if [[ ! "${phone_id}" =~ ^[0-9]+$ ]]; then
  printf 'El Phone Number ID debe contener solo números.\n' >&2
  exit 1
fi

if command -v zenity >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  access_token="$(zenity --password --title='Dental Americana' --text='Pegue el NUEVO access token temporal de Meta')" || exit 1
else
  read -r -s -p 'Nuevo access token temporal de Meta: ' access_token
  printf '\n'
fi
if [[ -z "${access_token}" ]]; then
  printf 'El access token es obligatorio.\n' >&2
  exit 1
fi

if command -v zenity >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  app_secret="$(zenity --password --title='Dental Americana' --text='Pegue el App Secret (App settings > Basic)')" || exit 1
else
  read -r -s -p 'App Secret (App settings > Basic): ' app_secret
  printf '\n'
fi
if [[ -z "${app_secret}" ]]; then
  printf 'El App Secret es obligatorio para validar webhooks entrantes.\n' >&2
  exit 1
fi

if command -v openssl >/dev/null 2>&1; then
  verify_token="$(openssl rand -hex 24)"
else
  verify_token="dental-$(date +%s)-${RANDOM}${RANDOM}"
fi

set_env WHATSAPP_ENABLED true
set_env WHATSAPP_GRAPH_BASE_URL https://graph.facebook.com/v25.0
set_env WHATSAPP_PHONE_NUMBER_ID "${phone_id}"
set_env WHATSAPP_ACCESS_TOKEN "${access_token}"
set_env WHATSAPP_APP_SECRET "${app_secret}"
set_env WHATSAPP_WEBHOOK_VERIFY_TOKEN "${verify_token}"

printf '\nConfiguración guardada en .env.\n'
printf 'Copia este Verify token en Meta (no es el access token):\n%s\n\n' "${verify_token}"
printf 'Siguiente comando:\n  %s start-demo\n' "${script_dir}/system.sh"
