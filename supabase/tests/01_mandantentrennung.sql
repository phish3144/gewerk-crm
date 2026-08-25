-- Mandantentrennung. Diese Tests versuchen aktiv, aus einem Betrieb in den
-- anderen zu greifen. Schlägt einer davon fehl, geht nichts weiter.
\set ON_ERROR_STOP on
\set QUIET on

-- ------------------------------------------------------------- Vorbereitung --
-- Als Eigentümerrolle, also an RLS vorbei: zwei Betriebe mit je einem Benutzer.
reset role;
truncate betrieb, benutzer cascade;
-- Das Journal wird NICHT geleert: es ist anfuegend (0011). Aussagen darueber
-- grenzen sich stattdessen auf den Mandanten dieses Tests ein.

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@bergmann-elektro.de',  'Anna Bergmann'),
  ('22222222-2222-2222-2222-222222222222', 'bruno@sued-haustechnik.de', 'Bruno Sued');

insert into betrieb (id, name) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Elektro Bergmann GmbH'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Sued Haustechnik e.K.');

insert into benutzer_betrieb (benutzer_id, betrieb_id, rolle) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'inhaber'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-0000-0000-0000-000000000002', 'inhaber');

insert into kunde (id, betrieb_id, name) values
  ('a1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Stadt Musterhausen'),
  ('b1000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'Wohnbau Sued AG');

insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('a2000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'Kita Ahornweg'),
  ('b2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'Heizung Talstrasse');

-- ------------------------------------------------- Anna sieht nur ihr Haus --
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare n integer;
begin
  select count(*) into n from kunde;
  if n <> 1 then raise exception 'FAIL Kunde: Anna sieht % Kunden statt 1', n; end if;

  select count(*) into n from kunde where betrieb_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  if n <> 0 then raise exception 'FAIL Durchgriff: Anna sieht % fremde Kunden', n; end if;

  select count(*) into n from projekt;
  if n <> 1 then raise exception 'FAIL Projekt: Anna sieht % Projekte statt 1', n; end if;

  select count(*) into n from betrieb;
  if n <> 1 then raise exception 'FAIL Betrieb: Anna sieht % Betriebe statt 1', n; end if;
end $$;

-- ------------------------------ Anna kann nicht in Brunos Betrieb schreiben --
do $$
begin
  begin
    insert into kunde (betrieb_id, name)
    values ('bbbbbbbb-0000-0000-0000-000000000002', 'Eingeschmuggelt');
    raise exception 'FAIL Insert: Anna durfte in Brunos Betrieb schreiben';
  exception when insufficient_privilege then null;
  end;
end $$;

-- --------------------------- Anna kann Brunos Zeilen nicht aendern/loeschen --
do $$
declare n integer;
begin
  update kunde set name = 'Uebernommen'
   where id = 'b1000000-0000-0000-0000-000000000002';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL Update: Anna hat % fremde Zeilen geaendert', n; end if;

  delete from kunde where id = 'b1000000-0000-0000-0000-000000000002';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL Delete: Anna hat % fremde Zeilen geloescht', n; end if;
end $$;

-- -------------- Anna kann sich nicht selbst in Brunos Betrieb einschreiben --
do $$
begin
  begin
    insert into benutzer_betrieb (benutzer_id, betrieb_id)
    values ('11111111-1111-1111-1111-111111111111', 'bbbbbbbb-0000-0000-0000-000000000002');
    raise exception 'FAIL Rechteausweitung: Anna konnte sich Brunos Betrieb zuordnen';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---------------- Anna kann einen eigenen Datensatz nicht umhaengen ---------
do $$
declare n integer;
begin
  begin
    update kunde set betrieb_id = 'bbbbbbbb-0000-0000-0000-000000000002'
     where id = 'a1000000-0000-0000-0000-000000000001';
    get diagnostics n = row_count;
    if n > 0 then
      raise exception 'FAIL Umhaengen: Anna hat einen Kunden in Brunos Betrieb verschoben';
    end if;
  exception when insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------- Bruno sieht spiegelbildlich ----
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare n integer; v_name text;
begin
  select count(*) into n from kunde;
  if n <> 1 then raise exception 'FAIL Bruno sieht % Kunden statt 1', n; end if;
  select name into v_name from kunde;
  if v_name <> 'Wohnbau Sued AG' then
    raise exception 'FAIL Bruno sieht den falschen Kunden: %', v_name;
  end if;
end $$;

-- ------------------------------------- Ohne Anmeldung ist nichts sichtbar ---
set request.jwt.claim.sub = '';
do $$
declare n integer;
begin
  select count(*) into n from kunde;
  if n <> 0 then raise exception 'FAIL Anonym: ohne Anmeldung sind % Kunden sichtbar', n; end if;
end $$;

reset role;
\echo '  OK  Mandantentrennung: 7 Angriffe abgewehrt'
