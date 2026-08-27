-- benutzer_betrieb.rolle existierte, wurde aber von keiner Policy gelesen:
-- jedes Konto im Betrieb hatte Vollzugriff, auch das Monteurkonto auf dem
-- Mobilgeraet. Und die Mandantenloeschung war nach der ersten festgeschriebenen
-- Rechnung dauerhaft unmoeglich - kein Weg fuer Austritt oder Art. 17 DSGVO.
\set ON_ERROR_STOP on
\set QUIET on

reset role;
truncate betrieb, benutzer cascade;

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@a.de', 'Anna'),
  ('44444444-4444-4444-4444-444444444444', 'dirk@a.de', 'Dirk'),
  ('33333333-3333-3333-3333-333333333333', 'carla@a.de', 'Carla');
insert into betrieb (id, name, iban) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'Betrieb A', 'DE00 1111 2222 3333 4444 00');
insert into benutzer_betrieb values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-00000000000a', 'inhaber'),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-00000000000a', 'buero'),
  ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-0000-0000-0000-00000000000a', 'monteur');
insert into kunde (id, betrieb_id, name) values
  ('a1000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a', 'Kunde A');
insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('a2000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a',
   'a1000000-0000-0000-0000-00000000000a', 'Baustelle');
insert into mitarbeiter (id, betrieb_id, name) values
  ('a3000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a', 'Dirk');

-- ------------------------------------------------------------- Monteur ------
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';

do $$
declare darf text[] := '{}'; n integer;
begin
  -- Lesen muss der Monteur duerfen, sonst ist die App unbrauchbar.
  select count(*) into n from kunde;
  if n <> 1 then raise exception 'FAIL Monteur sieht den Kundenstamm nicht'; end if;

  -- Schreiben auf kaufmaennischen Daten nicht.
  begin insert into kunde (betrieb_id, name)
        values ('aaaaaaaa-0000-0000-0000-00000000000a', 'Geschmuggelt');
        darf := array_append(darf, 'kunde anlegen'); exception when insufficient_privilege then null; end;
  begin update kunde set name = 'Umbenannt' where id = 'a1000000-0000-0000-0000-00000000000a';
        if found then darf := array_append(darf, 'kunde aendern'); end if;
        exception when insufficient_privilege then null; end;
  begin delete from kunde where id = 'a1000000-0000-0000-0000-00000000000a';
        if found then darf := array_append(darf, 'kunde loeschen'); end if;
        exception when insufficient_privilege then null; end;
  begin insert into beleg (betrieb_id, kunde_id, art, erstellt_von)
        values ('aaaaaaaa-0000-0000-0000-00000000000a', 'a1000000-0000-0000-0000-00000000000a',
                'angebot', '44444444-4444-4444-4444-444444444444');
        darf := array_append(darf, 'beleg anlegen'); exception when insufficient_privilege then null; end;
  -- Die IBAN des Betriebs steht auf jeder kuenftigen Rechnung.
  begin update betrieb set iban = 'DE99 6666 6666 6666 6666 99'
         where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
        if found then darf := array_append(darf, 'IBAN aendern'); end if;
        exception when insufficient_privilege then null; end;

  if array_length(darf, 1) > 0 then
    raise exception 'FAIL Monteur darf zu viel: %', array_to_string(darf, ', ');
  end if;
end $$;

-- Baustellendaten muss der Monteur schreiben duerfen.
do $$
declare v_doku uuid;
begin
  insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a2000000-0000-0000-0000-00000000000a', 'notiz', 'Durchbruch fehlt', now(),
          'a3000000-0000-0000-0000-00000000000a')
  returning id into v_doku;
  -- Ohne Position braucht die Buchung seit 0020 einen Nachweis - hier die
  -- Notiz von eben. Genau so ist es auch auf der Baustelle gemeint.
  insert into zeiteintrag (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende, nachweis_id)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a2000000-0000-0000-0000-00000000000a', 'a3000000-0000-0000-0000-00000000000a',
          now() - interval '4 hours', now(), v_doku);
  insert into materialentnahme (id, betrieb_id, projekt_id, bezeichnung, menge, einheit,
                                ek_preis, erfasst_am, erfasst_von, nachweis_id)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a2000000-0000-0000-0000-00000000000a', 'Bohrkrone 82 mm', 1, 'Stk', 48.90, now(),
          'a3000000-0000-0000-0000-00000000000a', v_doku);
exception when insufficient_privilege then
  raise exception 'FAIL Monteur kann nicht dokumentieren, Zeiten oder Material erfassen';
end $$;

-- --------------------------------------------------------------- Buero ------
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
declare darf text[] := '{}'; v uuid;
begin
  insert into beleg (betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', 'a1000000-0000-0000-0000-00000000000a',
          'schlussrechnung', current_date, '33333333-3333-3333-3333-333333333333')
  returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Leistung', 1, 1000);
  perform beleg_festschreiben(v);

  -- Die Bankverbindung bleibt dem Inhaber vorbehalten.
  begin update betrieb set iban = 'DE99 7777 7777 7777 7777 99'
         where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
        if found then darf := array_append(darf, 'IBAN aendern'); end if;
        exception when insufficient_privilege then null; end;
  if array_length(darf, 1) > 0 then
    raise exception 'FAIL Buero darf zu viel: %', array_to_string(darf, ', ');
  end if;
exception when insufficient_privilege then
  raise exception 'FAIL Buero kann nicht fakturieren';
end $$;

-- ------------------------------------------------- Mandantenloeschung -------
-- Der gewoehnliche Weg muss weiterhin scheitern: die Kaskade laeuft auf einen
-- festgeschriebenen Beleg.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
-- Zwei Ausgaenge sind zulaessig, und beide bedeuten "nicht geloescht":
-- entweder bricht die Kaskade am festgeschriebenen Beleg ab, oder RLS filtert
-- die Zeile weg, weil es fuer betrieb gar keine DELETE-Policy gibt. Geprueft
-- wird deshalb das Ergebnis, nicht die Ausnahme.
do $$
declare n integer;
begin
  begin
    delete from betrieb where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  exception when restrict_violation then null;
  end;
  select count(*) into n from betrieb where id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  if n <> 1 then
    raise exception 'FAIL Betrieb mit festgeschriebenem Beleg wurde am Schutz vorbei geloescht';
  end if;
end $$;

-- Der Monteur darf den Betrieb nicht loeschen.
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
do $$
begin
  perform betrieb_loeschen('aaaaaaaa-0000-0000-0000-00000000000a');
  raise exception 'FAIL Monteur konnte den Betrieb loeschen';
exception when insufficient_privilege then null;
end $$;

-- Der Inhaber kann es, und danach ist nichts mehr da - auch kein Journalrest.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select betrieb_loeschen('aaaaaaaa-0000-0000-0000-00000000000a');

reset role;
do $$
declare t text; rest text[] := '{}'; n integer;
begin
  for t in
    select c.relname from pg_class c join pg_namespace nn on nn.oid = c.relnamespace
     where nn.nspname = 'public' and c.relkind = 'r'
       and exists (select 1 from pg_attribute a
                    where a.attrelid = c.oid and a.attname = 'betrieb_id' and a.attnum > 0)
     order by c.relname
  loop
    execute format('select count(*) from %I where betrieb_id = %L',
                   t, 'aaaaaaaa-0000-0000-0000-00000000000a') into n;
    if n > 0 then rest := array_append(rest, t || ' (' || n || ')'); end if;
  end loop;
  if array_length(rest, 1) > 0 then
    raise exception 'FAIL nach der Loeschung verbleiben Zeilen in: %', array_to_string(rest, ', ');
  end if;
end $$;

\echo '  OK  Rollen: Monteur, Buero, Inhaber getrennt; Mandantenloeschung vollstaendig'
