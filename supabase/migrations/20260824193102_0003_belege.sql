-- Belegkette. Ein Belegtyp mit Unterscheidungsmerkmal statt getrennter
-- Tabellen: Angebot, Auftrag, Abschlags-, Teil- und Schlussrechnung teilen
-- Positionen, Summenlogik und Nummernkreise.

create type beleg_art as enum (
  'angebot', 'auftrag', 'abschlagsrechnung',
  'teilrechnung', 'schlussrechnung', 'gutschrift', 'storno'
);

create type beleg_status as enum (
  'entwurf',          -- änderbar, noch ohne Nummer
  'festgeschrieben',  -- unveränderlich, Nummer vergeben
  'versendet', 'angenommen', 'abgelehnt', 'bezahlt', 'storniert'
);

create table nummernkreis (
  betrieb_id uuid not null references betrieb(id) on delete cascade,
  art        beleg_art not null,
  jahr       smallint not null,
  praefix    text not null default '',
  naechste   integer not null default 1,
  primary key (betrieb_id, art, jahr),
  constraint nummernkreis_zaehler_positiv check (naechste >= 1)
);

create table beleg (
  id             uuid primary key default gen_random_uuid(),
  betrieb_id     uuid not null references betrieb(id) on delete cascade,
  kunde_id       uuid not null references kunde(id) on delete restrict,
  projekt_id     uuid references projekt(id) on delete set null,
  art            beleg_art not null,
  status         beleg_status not null default 'entwurf',
  nummer         text,
  -- Angebot -> Auftrag -> Rechnung. Die Kette bleibt nachvollziehbar, ohne
  -- dass Daten kopiert werden.
  vorgaenger_id  uuid references beleg(id) on delete set null,
  storniert_durch uuid references beleg(id) on delete set null,
  datum          date not null default current_date,
  -- § 14 Abs. 4 Nr. 6 UStG: Zeitpunkt der Lieferung oder sonstigen Leistung
  -- ist Pflichtangabe auf jeder Rechnung.
  leistungsdatum date,
  betreff        text,
  netto          numeric(14,2) not null default 0,
  steuer         numeric(14,2) not null default 0,
  brutto         numeric(14,2) not null default 0,
  festgeschrieben_am timestamptz,
  erstellt_von   uuid not null references benutzer(id) on delete restrict,
  erstellt_am    timestamptz not null default now(),

  -- Eine Nummer gibt es genau dann, wenn der Beleg festgeschrieben ist.
  -- Ein verworfener Entwurf hinterlässt damit keine Lücke im Nummernkreis.
  constraint beleg_nummer_bei_festschreibung check (
    (status = 'entwurf'  and nummer is null and festgeschrieben_am is null)
    or (status <> 'entwurf' and nummer is not null and festgeschrieben_am is not null)
  ),
  constraint beleg_summen_stimmig check (brutto = netto + steuer),
  unique (betrieb_id, art, nummer)
);
create index on beleg (betrieb_id);
create index on beleg (kunde_id);
create index on beleg (projekt_id);
create index on beleg (betrieb_id, status);

create type position_art as enum ('leistung', 'material', 'lohn', 'fremdleistung', 'text', 'titel');

create table beleg_position (
  id           uuid primary key default gen_random_uuid(),
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  beleg_id     uuid not null references beleg(id) on delete cascade,
  position_nr  integer not null,
  art          position_art not null default 'leistung',
  artikel_id   uuid references artikel(id) on delete set null,
  bezeichnung  text not null,
  menge        numeric(14,4) not null default 1,
  einheit      text not null default 'Stk',
  einzelpreis  numeric(14,2) not null default 0,
  rabatt_prozent numeric(5,2) not null default 0,
  steuersatz   numeric(5,2) not null default 19,

  -- Kalkulationsanteile je Einheit, nicht je Position. Ohne diese Trennung
  -- gibt es keine Nachkalkulation und keinen Deckungsbeitrag — bei plancraft
  -- ist genau das erst ab dem Pro-Tarif enthalten.
  lohn_anteil          numeric(14,2) not null default 0,
  material_anteil      numeric(14,2) not null default 0,
  fremdleistung_anteil numeric(14,2) not null default 0,
  lohn_minuten         integer not null default 0,

  -- Rückverweis in ein Leistungsverzeichnis (GAEB DA XML).
  gaeb_position text,

  -- Positionssumme wird gerechnet, nicht gespeichert-und-gehofft. Kaufmännisch
  -- wird je Position gerundet, dann summiert.
  gesamt numeric(14,2)
    generated always as (round(menge * einzelpreis * (1 - rabatt_prozent / 100), 2)) stored,

  constraint position_menge_nicht_negativ check (menge >= 0),
  constraint position_rabatt_plausibel check (rabatt_prozent >= 0 and rabatt_prozent < 100),
  constraint position_anteile_nicht_negativ check (
    lohn_anteil >= 0 and material_anteil >= 0 and fremdleistung_anteil >= 0
  ),
  constraint position_lohnminuten_nicht_negativ check (lohn_minuten >= 0),
  unique (beleg_id, position_nr)
);
create index on beleg_position (betrieb_id);
create index on beleg_position (beleg_id);

-- Summen aus den Positionen neu rechnen. Die Umsatzsteuer wird je Steuersatz
-- auf die Summe gerechnet, nicht je Position — sonst weichen Cent-Beträge ab.
create or replace function beleg_summen_neu(p_beleg uuid)
  returns void
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_netto  numeric(14,2);
  v_steuer numeric(14,2);
begin
  select coalesce(sum(gesamt), 0) into v_netto
    from beleg_position where beleg_id = p_beleg;

  select coalesce(sum(round(basis * satz / 100, 2)), 0) into v_steuer
    from (
      select steuersatz as satz, sum(gesamt) as basis
        from beleg_position
       where beleg_id = p_beleg
       group by steuersatz
    ) je_satz;

  update beleg
     set netto = v_netto, steuer = v_steuer, brutto = v_netto + v_steuer
   where id = p_beleg;
end $$;

-- Solange der Beleg Entwurf ist, hält der Kopf die Summen der Positionen.
-- Nach der Festschreibung sperrt der Unveränderbarkeits-Trigger aus 0005 jede
-- weitere Änderung, deshalb greift diese Funktion dann nicht mehr.
create or replace function beleg_position_summen_trigger()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_beleg uuid := coalesce(new.beleg_id, old.beleg_id);
begin
  perform beleg_summen_neu(v_beleg);
  return null;
end $$;

create trigger trg_beleg_position_summen
  after insert or update or delete on beleg_position
  for each row execute function beleg_position_summen_trigger();

-- Lückenlose Nummernvergabe. Eine Postgres-Sequence genügt nicht: sie verliert
-- Werte beim Rollback, und eine Lücke im Rechnungsnummernkreis ist ein
-- GoBD-Befund. FOR UPDATE serialisiert konkurrierende Festschreibungen.
create or replace function naechste_nummer(p_betrieb uuid, p_art beleg_art)
  returns text
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_jahr    smallint := extract(year from current_date)::smallint;
  v_nr      integer;
  v_praefix text;
begin
  select naechste, praefix into v_nr, v_praefix
    from nummernkreis
   where betrieb_id = p_betrieb and art = p_art and jahr = v_jahr
     for update;

  if not found then
    insert into nummernkreis (betrieb_id, art, jahr, naechste)
    values (p_betrieb, p_art, v_jahr, 2)
    returning 1, praefix into v_nr, v_praefix;
  else
    update nummernkreis set naechste = naechste + 1
     where betrieb_id = p_betrieb and art = p_art and jahr = v_jahr;
  end if;

  return format('%s%s-%s', v_praefix, v_jahr, lpad(v_nr::text, 5, '0'));
end $$;

-- Festschreiben ist der einzige Weg vom Entwurf in einen gültigen Beleg.
-- Danach ist der Beleg inhaltlich unveränderlich; Korrekturen laufen über
-- Storno und Neuausstellung.
create or replace function beleg_festschreiben(p_beleg uuid)
  returns text
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_beleg   beleg%rowtype;
  v_anzahl  integer;
  v_nummer  text;
begin
  select * into v_beleg from beleg where id = p_beleg for update;
  if not found then
    raise exception 'Beleg % existiert nicht', p_beleg;
  end if;
  if v_beleg.status <> 'entwurf' then
    raise exception 'Beleg % ist bereits festgeschrieben (Nummer %)', p_beleg, v_beleg.nummer;
  end if;

  select count(*) into v_anzahl
    from beleg_position where beleg_id = p_beleg and art not in ('text', 'titel');
  if v_anzahl = 0 then
    raise exception 'Beleg % hat keine abrechenbare Position', p_beleg;
  end if;

  -- § 14 Abs. 4 UStG: Pflichtangaben. Rechnungen ohne Leistungsdatum sind
  -- nicht vorsteuerabzugsfähig, deshalb wird hier hart abgebrochen.
  if v_beleg.art in ('abschlagsrechnung', 'teilrechnung', 'schlussrechnung')
     and v_beleg.leistungsdatum is null then
    raise exception 'Rechnung % braucht ein Leistungsdatum (§ 14 Abs. 4 Nr. 6 UStG)', p_beleg;
  end if;

  perform beleg_summen_neu(p_beleg);
  v_nummer := naechste_nummer(v_beleg.betrieb_id, v_beleg.art);

  update beleg
     set nummer = v_nummer,
         status = 'festgeschrieben',
         festgeschrieben_am = now()
   where id = p_beleg;

  return v_nummer;
end $$;
