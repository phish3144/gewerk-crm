-- NUR FÜR LOKALE TESTS. Bildet die Teile der Supabase-Plattform nach, die
-- dort bereits existieren: das auth-Schema, auth.uid() und die drei Rollen.
-- Diese Datei wird NIE auf ein Supabase-Projekt angewendet.
create schema if not exists auth;

create or replace function auth.uid() returns uuid
  language sql stable
  as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
