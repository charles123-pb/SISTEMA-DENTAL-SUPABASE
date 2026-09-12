#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
env_file="${project_dir}/.env"

value_of() {
  awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "${env_file}"
}

for key in WHATSAPP_PHONE_NUMBER_ID WHATSAPP_ACCESS_TOKEN WHATSAPP_APP_SECRET WHATSAPP_WEBHOOK_VERIFY_TOKEN; do
  if [[ -z "$(value_of "${key}")" ]]; then
    printf 'FALTA %s\n' "${key}" >&2
    exit 1
  fi
done

if [[ "$(value_of WHATSAPP_ENABLED)" != "true" ]]; then
  printf 'FALTA activar WHATSAPP_ENABLED=true\n' >&2
  exit 1
fi

if ! curl -fsS http://localhost/actuator/health >/dev/null; then
  printf 'ERROR: la API local no está saludable.\n' >&2
  exit 1
fi

graph_url="$(value_of WHATSAPP_GRAPH_BASE_URL)"
phone_id="$(value_of WHATSAPP_PHONE_NUMBER_ID)"
access_token="$(value_of WHATSAPP_ACCESS_TOKEN)"
http_code="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${access_token}" "${graph_url}/${phone_id}?fields=id")"

if [[ "${http_code}" != "200" ]]; then
  printf 'ERROR: Meta rechazó las credenciales (HTTP %s).\n' "${http_code}" >&2
  exit 1
fi

printf 'OK API local\nOK credenciales Meta\n'
if docker ps --format '{{.Names}}' | rg -xq dental-whatsapp-tunnel; then
  printf 'OK túnel temporal activo\n'
else
  printf 'PENDIENTE iniciar el túnel temporal\n'
fi
