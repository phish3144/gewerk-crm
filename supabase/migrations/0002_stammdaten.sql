-- Kunden, Mitarbeiter, Lieferanten, Artikel, Projekte.

create table kunde (
  id          uuid primary key default gen_random_uuid(),
  betrieb_id  uuid not null references betrieb(id) on delete cascade,
  nummer      text,
  name        text not null,
  strasse     text,
  plz         text,
  ort         text,
  ust_id      text,
  -- § 13b UStG: Bauleistungen an bauleistende Unternehmer gehen ohne
  -- Umsatzsteuer raus. Das Kennzeichen gehört an den Kunden, nicht an den
  -- Beleg — es ist eine Eigenschaft des Geschäftspartners.
  -- ACHTUNG: die steuerliche Behandlung ist noch nicht abschließend geklärt,
  -- siehe docs/offene-fragen.md Punkt 1. Das Feld hält die Information fest,
  -- die Rechnungslogik dazu fehlt bewusst noch.
  reverse_charge_bau boolean not null default false,
  zahlungsziel_tage  smallint not null default 14,
  skonto_prozent     numeric(5,2) not null default 0,
  skonto_tage        smallint not null default 0,
  angelegt_am timestamptz not null default now(),
  constraint kunde_name_nicht_leer check (length(btrim(name)) > 0),
  constraint kunde_skonto_plausibel check (skonto_prozent >= 0 and skonto_prozent < 100),
  unique (betrieb_id, nummer)
);
create index on kunde (betrieb_id);

create table ansprechpartner (
  id         uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null references betrieb(id) on delete cascade,
  kunde_id   uuid not null references kunde(id) on delete cascade,
  name       text not null,
  telefon    text,
  email      text
);
create index on ansprechpartner (betrieb_id);
create index on ansprechpartner (kunde_id);

create table mitarbeiter (
  id            uuid primary key default gen_random_uuid(),
  betrieb_id    uuid not null references betrieb(id) on delete cascade,
  benutzer_id   uuid references benutzer(id) on delete set null,
  name          text not null,
  kuerzel       text,
  -- Verrechnungssatz in Cent-genauer Währung, nicht als Fließkommazahl.
  stundensatz   numeric(14,2) not null default 0,
  aktiv         boolean not null default true,
  constraint mitarbeiter_satz_nicht_negativ check (stundensatz >= 0)
);
create index on mitarbeiter (betrieb_id);

create table lieferant (
  id             uuid primary key default gen_random_uuid(),
  betrieb_id     uuid not null references betrieb(id) on delete cascade,
  name           text not null,
  -- Subunternehmer sind Lieferanten, die zusätzlich auf der Plantafel
  -- einplanbar sind. Aus der Wettbewerbsanalyse: bei HERO ist genau das
  -- nicht möglich und wird von Nutzern als Lücke benannt.
  ist_subunternehmer boolean not null default false,
  -- IDS Connect 2.5 ist abwärtskompatibel zu 2.0 und 2.3; eine Implementierung
  -- muss ältere Marktpartner mitbedienen, deshalb wird die Version je
  -- Lieferant festgehalten.
  ids_version    text,
  ids_endpunkt   text,
  constraint lieferant_ids_version_bekannt
    check (ids_version is null or ids_version in ('2.0', '2.3', '2.5'))
);
create index on lieferant (betrieb_id);

create table artikel (
  id           uuid primary key default gen_random_uuid(),
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  nummer       text not null,
  bezeichnung  text not null,
  einheit      text not null default 'Stk',
  lieferant_id uuid references lieferant(id) on delete set null,
  ek_preis     numeric(14,2) not null default 0,
  vk_preis     numeric(14,2) not null default 0,
  steuersatz   numeric(5,2)  not null default 19,
  bestand      numeric(14,4) not null default 0,
  constraint artikel_preise_nicht_negativ check (ek_preis >= 0 and vk_preis >= 0),
  unique (betrieb_id, nummer)
);
create index on artikel (betrieb_id);

create type projekt_status as enum ('geplant', 'laufend', 'abgeschlossen', 'storniert');

create table projekt (
  id         uuid primary key default gen_random_uuid(),
  betrieb_id uuid not null references betrieb(id) on delete cascade,
  kunde_id   uuid not null references kunde(id) on delete restrict,
  nummer     text,
  bezeichnung text not null,
  strasse    text,
  plz        text,
  ort        text,
  status     projekt_status not null default 'geplant',
  beginn     date,
  ende       date,
  angelegt_am timestamptz not null default now(),
  constraint projekt_zeitraum_plausibel check (ende is null or beginn is null or ende >= beginn),
  unique (betrieb_id, nummer)
);
create index on projekt (betrieb_id);
create index on projekt (kunde_id);
