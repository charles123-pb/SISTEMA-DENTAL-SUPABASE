-- Aplicar después de crear project_url y whatsapp_cron_secret en Supabase Vault.
-- cron.schedule con el mismo nombre actualiza el trabajo existente.
select cron.schedule(
  'dental-whatsapp-dispatch',
  '* * * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/whatsapp-dispatch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'whatsapp_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $job$
);
