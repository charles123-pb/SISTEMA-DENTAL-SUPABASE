#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${script_dir}/.."
action="${1:-status}"
case "${action}" in
  start|start-demo|stop|status|check) ;;
  *) printf 'Uso: %s {start|start-demo|stop|status|check}\n' "$0" >&2; exit 2 ;;
esac
if [[ ! -f .env ]]; then
  printf 'Falta .env. Configure las variables siguiendo docs/PUESTA_EN_PRODUCCION.md\n' >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  printf 'Docker no está disponible para este usuario. Inicie Docker y ejecute con un usuario autorizado; en este equipo puede usar sudo ./ops/system.sh %s\n' "${action}" >&2
  exit 1
fi
export COMPOSE_PARALLEL_LIMIT=1
case "${action}" in
  start-demo)
    docker compose -f compose.full.yaml -f compose.demo.yaml config --quiet
    docker compose -f compose.full.yaml -f compose.demo.yaml up --build -d
    if rg -q '^WHATSAPP_ENABLED=true$' .env; then
      printf 'Entorno de prueba iniciado con WhatsApp habilitado. Abra http://localhost/sistema/login (o el WEB_PORT configurado).\n'
    else
      printf 'Entorno de prueba iniciado con WhatsApp deshabilitado. Abra http://localhost/sistema/login (o el WEB_PORT configurado).\n'
    fi
    ;;
  start)
    docker compose -f compose.full.yaml config --quiet
    docker compose -f compose.full.yaml up --build -d
    printf 'Consulte WEB_PORT en .env; con el valor predeterminado, abra http://localhost/sistema/login\n'
    ;;
  stop)
    docker compose -f compose.full.yaml stop
    printf 'Contenedores dentales detenidos. La base y los archivos se conservan.\n'
    ;;
  status) docker compose -f compose.full.yaml ps ;;
  check) "${script_dir}/verify-production.sh" "${2:-http://localhost}" ;;
esac
