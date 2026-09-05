#!/usr/bin/env bash
set -Eeuo pipefail

base_url="${1:-http://localhost}"
health="$(curl --fail --silent --show-error "${base_url}/actuator/health")"
case "${health}" in
  *'"status":"UP"'*) printf 'Backend saludable: %s\n' "${base_url}" ;;
  *) printf 'Respuesta de salud inesperada: %s\n' "${health}" >&2; exit 1 ;;
esac

curl --fail --silent --show-error "${base_url}/" >/dev/null
printf 'Frontend disponible: %s\n' "${base_url}"
