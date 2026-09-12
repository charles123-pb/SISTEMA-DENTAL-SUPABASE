-- Dependencias del despachador de mensajes automático.
-- El Job se configura fuera de las migraciones porque su secreto vive en Vault.
create extension if not exists pg_cron;
create extension if not exists pg_net;
