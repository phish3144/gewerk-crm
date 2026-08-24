-- Mandant, Benutzer, Zugehörigkeit und die zentrale Zugriffsfunktion.
-- Jede weitere Tabelle trägt betrieb_id — ohne Ausnahme.

create table betrieb (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  rechtsform   text,
  strasse      text,
  plz          text,
  ort          text,
  ust_id       text,
  steuernummer text,
  iban         text,
  angelegt_am  timestamptz not null default now(),
  constraint betrieb_name_nicht_leer check (length(btrim(name)) > 0)
);

-- Spiegelt auth.users. Supabase legt Benutzer dort an; hier hängen nur
-- die anwendungseigenen Felder.
create table benutzer (
  id          uuid primary key,
  email       text not null,
  anzeigename text not null,
  angelegt_am timestamptz not null default now()
);

create type betriebsrolle as enum ('inhaber', 'buero', 'monteur');

create table benutzer_betrieb (
  benutzer_id uuid not null references benutzer(id) on delete cascade,
  betrieb_id  uuid not null references betrieb(id)  on delete cascade,
  rolle       betriebsrolle not null default 'monteur',
  primary key (benutzer_id, betrieb_id)
);

-- Für die RLS-Policies entscheidend: der Index liegt auf benutzer_id,
-- weil die Funktion von der Person zur Menge ihrer Betriebe auflöst.
create index on benutzer_betrieb (benutzer_id);
create index on benutzer_betrieb (betrieb_id);

-- Die einzige Stelle, an der Zugehörigkeit bestimmt wird.
--
-- security definer, damit die Funktion benutzer_betrieb lesen darf, ohne dass
-- diese Tabelle selbst für jeden lesbar sein muss. stable, damit der Planer
-- das Ergebnis je Anweisung zwischenspeichern kann. auth.uid() steht in einem
-- Unterabfrage-SELECT — ohne diese Klammerung wertet Postgres die Funktion pro
-- Zeile aus (gemessen 179 ms gegen 9 ms auf 100.000 Zeilen).
--
-- search_path ist fest verdrahtet: eine security-definer-Funktion ohne festen
-- search_path lässt sich über eine untergeschobene Tabelle gleichen Namens
-- kapern.
create or replace function meine_betriebe()
  returns setof uuid
  language sql
  stable
  security definer
  set search_path = public, pg_temp
  as $$
    select bb.betrieb_id
      from benutzer_betrieb bb
     where bb.benutzer_id = (select auth.uid())
  $$;

revoke all on function meine_betriebe() from public;
grant execute on function meine_betriebe() to authenticated;
