#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
backup_dir="${1:-${project_dir}/backups}"
retention_days="${BACKUP_RETENTION_DAYS:-30}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "${backup_dir}"
database_tmp="${backup_dir}/dental_database_${timestamp}.dump.partial"
database_file="${backup_dir}/dental_database_${timestamp}.dump"
files_tmp="${backup_dir}/dental_files_${timestamp}.tar.gz.partial"
files_file="${backup_dir}/dental_files_${timestamp}.tar.gz"

cd "${project_dir}"
docker compose -f compose.full.yaml exec -T postgres sh -c \
  'exec pg_dump --format=custom --no-owner --no-privileges --username="$POSTGRES_USER" "$POSTGRES_DB"' \
  > "${database_tmp}"
mv "${database_tmp}" "${database_file}"

docker compose -f compose.full.yaml exec -T backend \
  tar -C /app/storage -czf - patients > "${files_tmp}"
mv "${files_tmp}" "${files_file}"

find "${backup_dir}" -maxdepth 1 -type f \
  \( -name 'dental_database_*.dump' -o -name 'dental_files_*.tar.gz' \) \
  -mtime "+${retention_days}" -delete

printf 'Respaldo creado:\n%s\n%s\n' "${database_file}" "${files_file}"
