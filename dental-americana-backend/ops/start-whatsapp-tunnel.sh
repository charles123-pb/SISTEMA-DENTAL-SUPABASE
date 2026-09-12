#!/usr/bin/env bash
set -Eeuo pipefail

container_name="dental-whatsapp-tunnel"

if [[ "${1:-}" == "--stop" ]]; then
  docker rm -f "${container_name}" >/dev/null 2>&1 || true
  printf 'Túnel temporal de WhatsApp detenido.\n'
  exit 0
fi

if ! docker info >/dev/null 2>&1; then
  printf 'Docker no está disponible para este usuario.\n' >&2
  exit 1
fi

docker rm -f "${container_name}" >/dev/null 2>&1 || true
docker run -d --name "${container_name}" --restart unless-stopped --network host \
  cloudflare/cloudflared:latest tunnel --no-autoupdate --url http://localhost:80 >/dev/null

for _ in {1..15}; do
  tunnel_url="$(docker logs "${container_name}" 2>&1 \
    | sed -n 's/.*\(https:\/\/[a-z0-9-]*\.trycloudflare\.com\).*/\1/p' | tail -1)"
  if [[ -n "${tunnel_url}" ]]; then
    printf 'Túnel temporal iniciado.\n'
    printf 'Callback URL para Meta:\n%s/api/v1/whatsapp/webhook\n' "${tunnel_url}"
    printf 'Para detenerlo: %s --stop\n' "$0"
    exit 0
  fi
  sleep 2
done

printf 'Cloudflare no devolvió una URL. Revise: docker logs %s\n' "${container_name}" >&2
exit 1
