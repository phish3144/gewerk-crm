-- Zwei kritische Befunde: der Mandantentest deckte nur 3 von 12 Policy-Tabellen
-- ab, und die Journal-Policy wurde von keinem Test beruehrt - ein
-- 'using (true)' waere nicht aufgefallen. Dazu drei weitere Luecken:
-- die Rolle anon wurde nie angenommen, benutzer_sichtbar nie geprueft, und
-- kein Test hatte einen Nutzer in zwei Betrieben.
--
-- Dieser Test ist absichtlich DATENGETRIEBEN: er liest die zu pruefenden
-- Tabellen aus dem Katalog statt aus einer gepflegten Liste. Eine spaeter
-- ergaenzte Tabelle mit betrieb_id ist damit automatisch mitgeprueft.
\set ON_ERROR_STOP on
\set QUIET on

reset role;
truncate betrieb, benutzer cascade;

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@a.de',  'Anna Albers'),
  ('22222222-2222-2222-2222-222222222222', 'bruno@b.de', 'Bruno Berger'),
  ('33333333-3333-3333-3333-333333333333', 'carla@c.de', 'Carla Conrad'),
  ('44444444-4444-4444-4444-444444444444', 'dirk@a.de',  'Dirk Deppe');
insert into betrieb (id, name) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'Betrieb A'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'Betrieb B');
insert into benutzer_betrieb values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-00000000000a', 'inhaber'),
  ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-0000-0000-0000-00000000000a', 'monteur'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-0000-0000-0000-00000000000b', 'inhaber'),
  -- Carla fuehrt zwei Schwesterbetriebe. Genau diese Konstellation sieht das
  -- Schema durch benutzer_betrieb ausdruecklich vor, und genau sie war ungeprueft.
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-00000000000a', 'buero'),
  ('33333333-3333-3333-3333-333333333333', 'bbbbbbbb-0000-0000-0000-00000000000b', 'buero');

-- Beide Betriebe vollstaendig bestuecken, damit jede Tabelle Zeilen hat.
do $$
declare
  b uuid; p text; inh uuid;
  v_kunde uuid; v_projekt uuid; v_ma uuid; v_lief uuid; v_beleg uuid; v_pos uuid;
begin
  foreach b in array array['aaaaaaaa-0000-0000-0000-00000000000a'::uuid,
                           'bbbbbbbb-0000-0000-0000-00000000000b'::uuid]
  loop
    p   := left(b::text, 1);
    inh := case when p = 'a' then '11111111-1111-1111-1111-111111111111'::uuid
                             else '22222222-2222-2222-2222-222222222222'::uuid end;

    insert into kunde (betrieb_id, name, zahlungsziel_tage)
      values (b, 'Kunde ' || upper(p), 14) returning id into v_kunde;
    insert into ansprechpartner (betrieb_id, kunde_id, name)
      values (b, v_kunde, 'Ansprechpartner ' || upper(p));
    insert into mitarbeiter (betrieb_id, name, stundensatz)
      values (b, 'Monteur ' || upper(p), 55) returning id into v_ma;
    insert into lieferant (betrieb_id, name, ids_version)
      values (b, 'Grosshandel ' || upper(p), '2.5') returning id into v_lief;
    insert into artikel (betrieb_id, nummer, bezeichnung, lieferant_id, ek_preis, vk_preis)
      values (b, 'ART-1', 'Leerrohr M25', v_lief, 0.1234, 0.1870);
    insert into projekt (betrieb_id, kunde_id, bezeichnung)
      values (b, v_kunde, 'Baustelle ' || upper(p)) returning id into v_projekt;
    insert into beleg (betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von)
      values (b, v_kunde, v_projekt, 'schlussrechnung', current_date, inh) returning id into v_beleg;
    insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
      values (b, v_beleg, 1, 'Position ' || upper(p), 10, 100) returning id into v_pos;
    insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von)
      values (gen_random_uuid(), b, v_projekt, 'notiz', 'Notiz ' || upper(p), now(), v_ma);
    insert into zeiteintrag (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende)
      values (gen_random_uuid(), b, v_projekt, v_ma, now() - interval '3 hours', now());
    insert into einsatz (betrieb_id, projekt_id, ressource_art, mitarbeiter_id, von, bis)
      values (b, v_projekt, 'mitarbeiter', v_ma, now(), now() + interval '4 hours');

    -- Festschreiben legt den Nummernkreis an und erzeugt Journalzeilen.
    perform set_config('request.jwt.claim.sub', inh::text, true);
    perform beleg_festschreiben(v_beleg);
  end loop;
end $$;

-- ----------------------------------------------------------- strukturell ----
-- Jede Tabelle mit betrieb_id MUSS RLS haben und mindestens eine Policy tragen.
-- Das faengt den Fall ab, dass jemand spaeter eine Tabelle ergaenzt und sie in
-- keiner Policy-Liste eintraegt.
do $$
declare ohne text[];
begin
  select array_agg(c.relname order by c.relname) into ohne
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and exists (select 1 from pg_attribute a
                  where a.attrelid = c.oid and a.attname = 'betrieb_id' and a.attnum > 0)
     and (not c.relrowsecurity
          or not exists (select 1 from pg_policy p where p.polrelid = c.oid));
  if ohne is not null then
    raise exception 'FAIL Tabellen mit betrieb_id ohne RLS oder ohne Policy: %', array_to_string(ohne, ', ');
  end if;
end $$;

-- ---------------------------------------------------- Mandant sieht nichts ---
-- Fuer JEDE Tabelle mit betrieb_id: Anna darf keine Zeile von Betrieb B sehen.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  t text; n integer; leck text[] := '{}'; geprueft integer := 0;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
       and exists (select 1 from pg_attribute a
                    where a.attrelid = c.oid and a.attname = 'betrieb_id' and a.attnum > 0)
     order by c.relname
  loop
    execute format('select count(*) from %I where betrieb_id = %L',
                   t, 'bbbbbbbb-0000-0000-0000-00000000000b') into n;
    geprueft := geprueft + 1;
    if n > 0 then leck := array_append(leck, t || ' (' || n || ')'); end if;
  end loop;

  if array_length(leck, 1) > 0 then
    raise exception 'FAIL fremde Zeilen sichtbar in: %', array_to_string(leck, ', ');
  end if;
  if geprueft < 12 then
    raise exception 'FAIL nur % Tabellen geprueft, erwartet mindestens 12', geprueft;
  end if;
  raise notice '% Tabellen auf Mandantentrennung geprueft', geprueft;
end $$;

-- Das Journal ist die dichteste Datenquelle im Schema: vorher/nachher enthalten
-- vollstaendige Zeilenabbilder mit Kundenbezug, Betraegen und Stundensaetzen.
do $$
declare n integer; eigen integer;
begin
  select count(*) into n     from journal where betrieb_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
  select count(*) into eigen from journal where betrieb_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  if n > 0 then raise exception 'FAIL Journal von Betrieb B sichtbar: % Zeilen', n; end if;
  if eigen = 0 then raise exception 'FAIL eigenes Journal nicht sichtbar - Policy zu streng oder Trigger fehlt'; end if;
end $$;

-- Die Journal-Sequenz ist betriebsuebergreifend: an den Luecken zwischen den
-- eigenen IDs liesse sich das Schreibaufkommen fremder Mandanten ablesen.
-- Die Spalte darf die Anwendungsrolle deshalb gar nicht erst sehen.
do $$
declare n bigint;
begin
  begin
    execute 'select max(id) from journal' into n;
    raise exception 'FAIL journal.id ist fuer die Anwendungsrolle lesbar - Seitenkanal auf fremdes Volumen';
  exception when insufficient_privilege then null;
  end;
  -- Die fachlichen Spalten muessen dabei weiterhin lesbar bleiben.
  execute 'select count(*) from (select tabelle, aktion, erfasst_am from journal) q' into n;
end $$;

-- ------------------------------------------------------- benutzer_sichtbar ---
-- Die einzige handgeschriebene Policy mit zusammengesetzter Bedingung, und
-- damit die fehleranfaelligste. Es geht um Klarnamen und E-Mail-Adressen.
do $$
declare selbst integer; kollege integer; fremd integer;
begin
  select count(*) into selbst  from benutzer where id = '11111111-1111-1111-1111-111111111111';
  select count(*) into kollege from benutzer where id = '44444444-4444-4444-4444-444444444444';
  select count(*) into fremd   from benutzer where id = '22222222-2222-2222-2222-222222222222';
  if selbst  <> 1 then raise exception 'FAIL Anna sieht sich selbst nicht'; end if;
  if kollege <> 1 then raise exception 'FAIL Anna sieht ihren Kollegen nicht'; end if;
  if fremd   <> 0 then raise exception 'FAIL Anna sieht Bruno aus einem fremden Betrieb'; end if;
end $$;

-- -------------------------------------------------- Nutzer in zwei Betrieben --
-- meine_betriebe() liefert setof uuid. Jede Implementierung, die still auf
-- einen Wert schrumpft (limit 1, skalarer Vergleich), bestand bisher die
-- gesamte Suite.
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$
declare n integer; k integer;
begin
  select count(*) into n from meine_betriebe();
  if n <> 2 then raise exception 'FAIL Carla gehoert zu 2 Betrieben, meine_betriebe() liefert %', n; end if;
  select count(distinct betrieb_id) into k from kunde;
  if k <> 2 then raise exception 'FAIL Carla sieht Kunden aus % Betrieben statt 2', k; end if;
end $$;

-- ------------------------------------------------------------------ anon -----
-- Der bisherige Block "ohne Anmeldung" setzte nur auth.uid() auf leer, blieb
-- aber in der Rolle authenticated. Die Rolle anon kam in keiner Testdatei vor.
reset role;
set role anon;
set request.jwt.claim.sub = '';
do $$
declare t text; n integer; leck text[] := '{}';
begin
  for t in
    select c.relname from pg_class c join pg_namespace n2 on n2.oid = c.relnamespace
     where n2.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
     order by c.relname
  loop
    begin
      execute format('select count(*) from %I', t) into n;
      if n > 0 then leck := array_append(leck, t || ' (' || n || ')'); end if;
    exception when insufficient_privilege then null;   -- kein Recht ist das gewuenschte Ergebnis
    end;
  end loop;
  if array_length(leck, 1) > 0 then
    raise exception 'FAIL ohne Anmeldung sichtbar: %', array_to_string(leck, ', ');
  end if;
end $$;

reset role;
\echo '  OK  Policy-Abdeckung: alle Tabellen mit betrieb_id, Journal, benutzer, anon, Mehrfachzugehoerigkeit'
