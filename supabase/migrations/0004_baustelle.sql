-- Baustellendokumentation, Zeiterfassung, Disposition.

create type doku_art as enum ('foto', 'notiz', 'aufmass', 'sprachnotiz');

create table dokumentation (
  -- Die ID kommt vom Client, nicht aus der Datenbank. Das macht den Upload
  -- aus der Offline-Warteschlange idempotent: ein doppelt gesendeter Eintrag
  -- erzeugt keinen zweiten Datensatz.
  id           uuid primary key,
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  projekt_id   uuid not null references projekt(id) on delete cascade,
  art          doku_art not null,
  -- Nur der Objektschlüssel. Die Datei liegt in R2 (kostenloser Egress),
  -- nicht in der Datenbank und nicht in Supabase Storage.
  r2_key       text,
  text         text,
  aufmass      jsonb,
  -- Zwei Zeitpunkte: erfasst_am kommt vom Gerät und kann Tage zurückliegen,
  -- hochgeladen_am vom Server. Für die Doku zählt der erste, für die
  -- Nachvollziehbarkeit der zweite.
  erfasst_am     timestamptz not null,
  hochgeladen_am timestamptz not null default now(),
  erfasst_von    uuid not null references mitarbeiter(id) on delete restrict,
  constraint doku_inhalt_vorhanden check (
    r2_key is not null or text is not null or aufmass is not null
  ),
  constraint doku_foto_braucht_datei check (art <> 'foto' or r2_key is not null)
);
create index on dokumentation (betrieb_id);
create index on dokumentation (projekt_id, erfasst_am desc);

create table zeiteintrag (
  id           uuid primary key,          -- ebenfalls client-generiert
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  projekt_id   uuid references projekt(id) on delete set null,
  mitarbeiter_id uuid not null references mitarbeiter(id) on delete restrict,
  beginn       timestamptz not null,
  ende         timestamptz,
  pause_minuten integer not null default 0,
  taetigkeit   text,
  -- Verweis auf die Position, die diese Stunden abrechnet. Solange NULL, sind
  -- die Stunden erfasst aber nicht abgerechnet — die Kennzahl, die auf der
  -- Übersicht als "nicht abgerechnet" steht.
  position_id  uuid references beleg_position(id) on delete set null,
  freigegeben_am timestamptz,
  constraint zeit_ende_nach_beginn check (ende is null or ende > beginn),
  constraint zeit_pause_nicht_negativ check (pause_minuten >= 0),
  constraint zeit_pause_kuerzer_als_zeitraum check (
    ende is null or pause_minuten * interval '1 minute' < (ende - beginn)
  )
);
create index on zeiteintrag (betrieb_id);
create index on zeiteintrag (mitarbeiter_id, beginn desc);
create index on zeiteintrag (projekt_id);
-- Für die Kennzahl "nicht abgerechnete Stunden".
create index on zeiteintrag (betrieb_id, position_id) where position_id is null;

create type ressource_art as enum ('mitarbeiter', 'subunternehmer', 'geraet');

create table einsatz (
  id         uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null references betrieb(id) on delete cascade,
  projekt_id uuid not null references projekt(id) on delete cascade,
  -- Fremdleistung ist von Anfang an planbare Ressource, nicht nur Kostenart.
  -- Aus der Wettbewerbsanalyse: bei HERO lassen sich Subunternehmer nicht
  -- direkt einplanen, was Nutzer ausdrücklich bemängeln.
  ressource_art     ressource_art not null,
  mitarbeiter_id    uuid references mitarbeiter(id) on delete cascade,
  subunternehmer_id uuid references lieferant(id) on delete cascade,
  bezeichnung       text,
  von        timestamptz not null,
  bis        timestamptz not null,
  constraint einsatz_zeitraum check (bis > von),
  constraint einsatz_ressource_passend check (
    (ressource_art = 'mitarbeiter'    and mitarbeiter_id is not null and subunternehmer_id is null)
    or (ressource_art = 'subunternehmer' and subunternehmer_id is not null and mitarbeiter_id is null)
    or (ressource_art = 'geraet'         and mitarbeiter_id is null and subunternehmer_id is null
        and bezeichnung is not null)
  )
);
create index on einsatz (betrieb_id);
create index on einsatz (projekt_id);
create index on einsatz (betrieb_id, von, bis);

-- Ein Mitarbeiter kann nicht zeitgleich auf zwei Baustellen stehen. Der
-- Ausschluss greift nur für Mitarbeiter — Geräte und Subunternehmer haben
-- eigene Regeln.
create extension if not exists btree_gist;
alter table einsatz add constraint einsatz_mitarbeiter_ohne_ueberschneidung
  exclude using gist (
    mitarbeiter_id with =,
    tstzrange(von, bis) with &&
  ) where (ressource_art = 'mitarbeiter');
