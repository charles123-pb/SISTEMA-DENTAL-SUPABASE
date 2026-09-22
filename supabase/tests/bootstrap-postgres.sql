-- Exclusivo para un PostgreSQL vacío de pruebas; no ejecutar en Supabase real.
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
create function auth.role() returns text language sql as $$ select 'service_role'::text $$;
create schema storage;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid,name text,bucket_id text);
create function storage.foldername(text) returns text[] language sql as $$ select string_to_array($1,'/') $$;
create publication supabase_realtime;
