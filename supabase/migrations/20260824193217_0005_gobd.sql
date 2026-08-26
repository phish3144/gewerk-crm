-- GoBD: Unveränderbarkeit und Nachvollziehbarkeit. Alles in der Datenbank,
-- nichts im Anwendungscode — was nur die Anwendung durchsetzt, setzt ein
-- direkter Datenbankzugriff außer Kraft.

-- ---------------------------------------------------------------- Journal --
create table journal (
  id           bigint generated always as identity primary key,
  betrieb_id   uuid not null,
  tabelle      text not null,
  datensatz_id text not null,
  aktion       text not null,
  vorher       jsonb,
  nachher      jsonb,
  benutzer_id  uuid,
  erfasst_am   timestamptz not null default now(),
  constraint journal_aktion_bekannt check (aktion in ('insert', 'update', 'delete'))
);
create index on journal (betrieb_id, erfasst_am desc);
create index on journal (tabelle, datensatz_id);

create or replace function journal_schreiben()
  returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_betrieb uuid;
  v_id      text;
begin
  v_betrieb := coalesce(
    (case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end ->> 'betrieb_id')::uuid
  );
  v_id := case when tg_op = 'DELETE' then to_jsonb(old) ->> 'id' else to_jsonb(new) ->> 'id' end;

  insert into journal (betrieb_id, tabelle, datensatz_id, aktion, vorher, nachher, benutzer_id)
  values (
    v_betrieb,
    tg_table_name,
    v_id,
    lower(tg_op),
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end,
    (select auth.uid())
  );
  return null;
end $$;

create trigger trg_journal_beleg
  after insert or update or delete on beleg
  for each row execute function journal_schreiben();
create trigger trg_journal_beleg_position
  after insert or update or delete on beleg_position
  for each row execute function journal_schreiben();
create trigger trg_journal_zeiteintrag
  after insert or update or delete on zeiteintrag
  for each row execute function journal_schreiben();

-- Das Journal ist anfügend. Ändern und Löschen sind auf Datenbankebene
-- entzogen, auch für die Anwendungsrolle.
revoke update, delete, truncate on journal from public;

-- ------------------------------------------------------- Unveränderbarkeit --
-- Nach der Festschreibung dürfen nur noch status und storniert_durch wandern.
-- Jede inhaltliche Änderung bricht ab; Korrekturen laufen über Storno und
-- Neuausstellung, was zugleich der Weg ist, den Prüfer erwarten.
create or replace function beleg_unveraenderlich()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if old.status = 'entwurf' then
    return new;
  end if;

  if new.betrieb_id         is distinct from old.betrieb_id
  or new.kunde_id           is distinct from old.kunde_id
  or new.projekt_id         is distinct from old.projekt_id
  or new.art                is distinct from old.art
  or new.nummer             is distinct from old.nummer
  or new.datum              is distinct from old.datum
  or new.leistungsdatum     is distinct from old.leistungsdatum
  or new.betreff            is distinct from old.betreff
  or new.netto              is distinct from old.netto
  or new.steuer             is distinct from old.steuer
  or new.brutto             is distinct from old.brutto
  or new.vorgaenger_id      is distinct from old.vorgaenger_id
  or new.festgeschrieben_am is distinct from old.festgeschrieben_am
  or new.erstellt_von       is distinct from old.erstellt_von
  or new.erstellt_am        is distinct from old.erstellt_am
  then
    raise exception
      'Beleg % ist festgeschrieben und inhaltlich unveraenderlich (GoBD). Korrektur nur ueber Storno und Neuausstellung.',
      coalesce(old.nummer, old.id::text)
      using errcode = 'restrict_violation';
  end if;

  return new;
end $$;

create trigger trg_beleg_unveraenderlich
  before update on beleg
  for each row execute function beleg_unveraenderlich();

create or replace function beleg_nicht_loeschbar()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if old.status <> 'entwurf' then
    raise exception
      'Beleg % ist festgeschrieben und nicht loeschbar (GoBD). Stattdessen stornieren.',
      coalesce(old.nummer, old.id::text)
      using errcode = 'restrict_violation';
  end if;
  return old;
end $$;

create trigger trg_beleg_nicht_loeschbar
  before delete on beleg
  for each row execute function beleg_nicht_loeschbar();

-- Positionen eines festgeschriebenen Belegs sind ebenfalls gesperrt — sonst
-- ließe sich der Inhalt ändern, während der Kopf unberührt bleibt.
create or replace function position_unveraenderlich()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_status beleg_status;
  v_beleg  uuid := coalesce(new.beleg_id, old.beleg_id);
begin
  select status into v_status from beleg where id = v_beleg;
  if v_status is not null and v_status <> 'entwurf' then
    raise exception
      'Positionen des festgeschriebenen Belegs % sind unveraenderlich (GoBD).', v_beleg
      using errcode = 'restrict_violation';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create trigger trg_position_unveraenderlich
  before insert or update or delete on beleg_position
  for each row execute function position_unveraenderlich();

-- Nummernkreise dürfen nicht zurückgedreht werden. Ein rückwärts gesetzter
-- Zähler erzeugt doppelte Rechnungsnummern.
create or replace function nummernkreis_nur_vorwaerts()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if new.naechste < old.naechste then
    raise exception 'Nummernkreis darf nicht zurueckgesetzt werden (% -> %)', old.naechste, new.naechste
      using errcode = 'restrict_violation';
  end if;
  return new;
end $$;

create trigger trg_nummernkreis_nur_vorwaerts
  before update on nummernkreis
  for each row execute function nummernkreis_nur_vorwaerts();
