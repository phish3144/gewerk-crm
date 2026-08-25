-- Preisgenauigkeit, Faelligkeit, Belegdatum, Summenbildung und die
-- vollstaendige Pruefung der geschuetzten Spalten.
\set ON_ERROR_STOP on
\set QUIET on

reset role;
truncate betrieb, benutzer cascade;

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@a.de', 'Anna');
insert into betrieb (id, name) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'Betrieb A');
insert into benutzer_betrieb values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-00000000000a', 'inhaber');
insert into kunde (id, betrieb_id, name, zahlungsziel_tage, skonto_prozent, skonto_tage) values
  ('a1000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a',
   'Stadt Musterhausen', 30, 3, 10);

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ----------------------------------------------------- Preisgenauigkeit -----
-- NYM-J 3x1,5 zu 0,1870 EUR/m auf 5.000 m. Mit numeric(14,2) wurde daraus
-- 0,19 EUR/m und 950,00 EUR statt 935,00 EUR - 1,6 % zu viel.
do $$
declare v uuid; g numeric; ep numeric;
begin
  insert into beleg (id, betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'schlussrechnung', current_date,
          '11111111-1111-1111-1111-111111111111') returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'NYM-J 3x1,5', 5000, 0.1870);

  select einzelpreis, gesamt into ep, g from beleg_position where beleg_id = v;
  if ep <> 0.1870 then raise exception 'FAIL Einzelpreis gerundet: % statt 0.1870', ep; end if;
  if g  <> 935.00 then raise exception 'FAIL Positionssumme % statt 935.00', g; end if;
  delete from beleg_position where beleg_id = v;
  delete from beleg where id = v;
end $$;

-- Auch der Artikelstamm: EK verfaelscht sonst jede Nachkalkulation.
do $$
declare ek numeric;
begin
  insert into artikel (betrieb_id, nummer, bezeichnung, ek_preis, vk_preis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', 'NYM-3x1.5', 'NYM-J 3x1,5', 0.1234, 0.1870);
  select ek_preis into ek from artikel where nummer = 'NYM-3x1.5';
  if ek <> 0.1234 then raise exception 'FAIL EK-Preis gerundet: % statt 0.1234', ek; end if;
end $$;

-- --------------------------------------------------- Summen je Anweisung ----
-- Der alte Trigger lief je Zeile: bei N Positionen N Aggregationen und N
-- UPDATEs auf dem Kopf, jedes davon mit eigener Journalzeile.
do $$
declare v uuid; n numeric; j integer;
begin
  insert into beleg (id, betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'schlussrechnung', current_date,
          '11111111-1111-1111-1111-111111111111') returning id into v;

  -- Fuenf Positionen in EINER Anweisung.
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  select 'aaaaaaaa-0000-0000-0000-00000000000a', v, i, 'Position ' || i, 1, 100
    from generate_series(1, 5) i;

  select netto into n from beleg where id = v;
  if n <> 500.00 then raise exception 'FAIL Kopfsumme % statt 500.00', n; end if;

  select count(*) into j from journal
   where tabelle = 'beleg' and datensatz_id = v::text and aktion = 'update';
  if j <> 1 then
    raise exception 'FAIL % Kopf-Aktualisierungen fuer eine Anweisung, erwartet 1', j;
  end if;

  -- Massenaenderung und Massenloeschung ebenfalls je Anweisung.
  update beleg_position set einzelpreis = 200 where beleg_id = v;
  select netto into n from beleg where id = v;
  if n <> 1000.00 then raise exception 'FAIL nach Massenaenderung % statt 1000.00', n; end if;

  delete from beleg_position where beleg_id = v and position_nr > 2;
  select netto into n from beleg where id = v;
  if n <> 400.00 then raise exception 'FAIL nach Massenloeschung % statt 400.00', n; end if;
end $$;

-- ------------------------------------------------- Belegdatum und Faelligkeit --
do $$
declare v uuid;
begin
  insert into beleg (id, betrieb_id, kunde_id, art, datum, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'schlussrechnung',
          current_date + 5, current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Leistung', 1, 100);
  begin
    perform beleg_festschreiben(v);
    raise exception 'FAIL Beleg mit Datum in der Zukunft wurde festgeschrieben';
  exception when restrict_violation then null;
  end;
end $$;

do $$
declare v uuid; f date; d date; z smallint; sp numeric;
begin
  insert into beleg (id, betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'schlussrechnung', current_date,
          '11111111-1111-1111-1111-111111111111') returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Leistung', 1, 10000);
  perform beleg_festschreiben(v);

  select datum, faelligkeit_am, zahlungsziel_tage, skonto_prozent
    into d, f, z, sp from beleg where id = v;
  if z <> 30  then raise exception 'FAIL Zahlungsziel nicht eingefroren: %', z; end if;
  if sp <> 3  then raise exception 'FAIL Skonto nicht eingefroren: %', sp; end if;
  if f <> d + 30 then raise exception 'FAIL Faelligkeit % statt %', f, d + 30; end if;

  -- Die Konditionen des Kunden aendern sich - die Rechnung darf das nicht mitmachen.
  update kunde set zahlungsziel_tage = 7, skonto_prozent = 0
   where id = 'a1000000-0000-0000-0000-00000000000a';
  select faelligkeit_am, zahlungsziel_tage into f, z from beleg where id = v;
  if z <> 30 or f <> d + 30 then
    raise exception 'FAIL Rechnung folgt nachtraeglich den Kundenkonditionen: % / %', z, f;
  end if;
  perform set_config('test.beleg', v::text, false);
end $$;

-- ------------------------------- alle geschuetzten Spalten, datengetrieben ---
-- Die Unveraenderbarkeit wurde bisher nur an netto und nummer geprueft. Die
-- Spaltenliste wird jetzt aus der Funktion selbst gelesen: wer eine Spalte
-- ergaenzt, bekommt den Test automatisch mit.
do $$
declare
  v      uuid := current_setting('test.beleg')::uuid;
  def    text := pg_get_functiondef('beleg_unveraenderlich()'::regprocedure);
  spalte text;
  typ    text;
  satz   text;
  offen  text[] := '{}';
  anzahl integer := 0;
begin
  for spalte in
    select distinct m[1] from regexp_matches(def, 'new\.(\w+)\s+is distinct from old\.\1', 'g') m
    order by 1
  loop
    -- storniert_durch ist nicht unveraenderlich, sondern EINMAL beschreibbar:
    -- solange kein Storno vermerkt ist, darf es gesetzt werden. Seine eigene
    -- Pruefung steht in 04_gobd.sql. Alle uebrigen Spalten sind absolut.
    if spalte = 'storniert_durch' then continue; end if;

    select data_type into typ from information_schema.columns
     where table_schema = 'public' and table_name = 'beleg' and column_name = spalte;

    satz := case typ
      when 'text'                        then format('%I = coalesce(%I, '''') || ''X''', spalte, spalte)
      when 'uuid'                        then format('%I = gen_random_uuid()', spalte)
      when 'date'                        then format('%I = coalesce(%I, current_date) + 1', spalte, spalte)
      when 'numeric'                     then format('%I = coalesce(%I, 0) + 1', spalte, spalte)
      when 'smallint'                    then format('%I = coalesce(%I, 0) + 1', spalte, spalte)
      when 'integer'                     then format('%I = coalesce(%I, 0) + 1', spalte, spalte)
      when 'timestamp with time zone'    then format('%I = coalesce(%I, now()) + interval ''1 day''', spalte, spalte)
      when 'USER-DEFINED'                then format('%I = ''gutschrift''::beleg_art', spalte)
      else null end;

    if satz is null then
      raise exception 'FAIL Spalte % hat den ungeprueften Typ % - Test erweitern', spalte, typ;
    end if;

    anzahl := anzahl + 1;
    begin
      execute format('update beleg set %s where id = %L', satz, v);
      offen := array_append(offen, spalte);
    exception when restrict_violation then null;
    end;
  end loop;

  if array_length(offen, 1) > 0 then
    raise exception 'FAIL geschuetzte Spalten liessen sich aendern: %', array_to_string(offen, ', ');
  end if;
  if anzahl < 20 then
    raise exception 'FAIL nur % Spalten geprueft, erwartet mindestens 20', anzahl;
  end if;
  raise notice '% geschuetzte Spalten einzeln geprueft', anzahl;
end $$;

-- --------------------------------------------- Journal fuehrt alles mit -----
do $$
declare v uuid; i integer; u integer; d integer; mit_vorher integer;
begin
  -- Ein Entwurf, der wieder verworfen wird, muss als delete im Journal stehen.
  insert into beleg (id, betrieb_id, kunde_id, art, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'angebot',
          '11111111-1111-1111-1111-111111111111') returning id into v;
  delete from beleg where id = v;

  select count(*) filter (where aktion = 'insert'),
         count(*) filter (where aktion = 'update'),
         count(*) filter (where aktion = 'delete'),
         count(*) filter (where aktion in ('update','delete') and vorher is not null)
    into i, u, d, mit_vorher
    from journal where tabelle = 'beleg'
                   and betrieb_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  if i = 0 then raise exception 'FAIL Journal ohne insert'; end if;
  if u = 0 then raise exception 'FAIL Journal ohne update'; end if;
  if d = 0 then raise exception 'FAIL Journal ohne delete - Aenderungen sind nicht nachvollziehbar'; end if;
  if mit_vorher <> u + d then
    raise exception 'FAIL % von % Aenderungen ohne vorher-Abbild', (u + d) - mit_vorher, u + d;
  end if;
end $$;

reset role;
\echo '  OK  Praezision, Faelligkeit, Belegdatum, Summen je Anweisung, alle geschuetzten Spalten'
