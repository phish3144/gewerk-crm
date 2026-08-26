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

-- Supabase vergibt im Schema public Standardrechte (alter default privileges,
-- erteilt von der Rolle postgres, unter der auch die Migrationen laufen). Jede
-- neu angelegte Tabelle und jede neue Funktion bekommt dadurch automatisch
-- Rechte fuer anon und authenticated - einschliesslich TRUNCATE und EXECUTE.
--
-- Ohne diese Zeilen testet der lokale Lauf eine Datenbank, die strenger ist als
-- die echte: es fehlt schlicht das Recht, das in Produktion vorhanden ist. Genau
-- daran ist der erste Durchgang vorbeigelaufen. Die Werte sind 1:1 aus
-- pg_default_acl des Projekts uebernommen.
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public
  grant usage, select, update on sequences to anon, authenticated, service_role;
