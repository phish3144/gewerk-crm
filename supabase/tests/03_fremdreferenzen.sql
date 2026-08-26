-- Mandantenuebergreifende Verweise. Der schwerste Befund der adversarialen
-- Pruefung: Policies pruefen nur die betrieb_id der eigenen Zeile, nie den
-- Mandanten der referenzierten Zeile. Seit 0008 tragen alle Fremdschluessel
-- das Paar (betrieb_id, id) - ein Fremdverweis ist damit nicht mehr verboten,
-- sondern nicht mehr formulierbar.
\set ON_ERROR_STOP on
\set QUIET on

reset role;
truncate betrieb, benutzer cascade;
-- Das Journal wird NICHT geleert: es ist anfuegend (0011). Aussagen darueber
-- grenzen sich stattdessen auf den Mandanten dieses Tests ein.

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@a.de',  'Anna'),
  ('22222222-2222-2222-2222-222222222222', 'bruno@b.de', 'Bruno');
insert into betrieb (id, name) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'Betrieb A'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'Betrieb B');
insert into benutzer_betrieb values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-00000000000a', 'inhaber'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-0000-0000-0000-00000000000b', 'inhaber');

-- Betrieb A
insert into kunde       (id, betrieb_id, name) values ('a1000000-0000-0000-0000-00000000000a','aaaaaaaa-0000-0000-0000-00000000000a','Kunde A');
insert into projekt     (id, betrieb_id, kunde_id, bezeichnung) values ('a2000000-0000-0000-0000-00000000000a','aaaaaaaa-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-00000000000a','Projekt A');
insert into mitarbeiter (id, betrieb_id, name) values ('a3000000-0000-0000-0000-00000000000a','aaaaaaaa-0000-0000-0000-00000000000a','Monteur A');
insert into lieferant   (id, betrieb_id, name) values ('a5000000-0000-0000-0000-00000000000a','aaaaaaaa-0000-0000-0000-00000000000a','Lieferant A');

-- Betrieb B, inklusive festgeschriebener Rechnung
insert into kunde       (id, betrieb_id, name) values ('b1000000-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-00000000000b','Kunde B');
insert into projekt     (id, betrieb_id, kunde_id, bezeichnung) values ('b2000000-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-00000000000b','b1000000-0000-0000-0000-00000000000b','Projekt B');
insert into mitarbeiter (id, betrieb_id, name) values ('b3000000-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-00000000000b','Monteur B');
insert into lieferant   (id, betrieb_id, name) values ('b5000000-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-00000000000b','Lieferant B');
insert into beleg (id, betrieb_id, kunde_id, art, leistungsdatum, erstellt_von) values
  ('b4000000-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-00000000000b','b1000000-0000-0000-0000-00000000000b','schlussrechnung',current_date,'22222222-2222-2222-2222-222222222222');
insert into beleg_position (id, betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis) values
  ('b6000000-0000-0000-0000-00000000000b','bbbbbbbb-0000-0000-0000-00000000000b','b4000000-0000-0000-0000-00000000000b',1,'Brennwertkessel',1,8000);
-- Festschreiben erfolgt als Bruno, also mit echter Anwendungsrolle.
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select beleg_festschreiben('b4000000-0000-0000-0000-00000000000b') \gset weg_
reset role;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- Jeder Block versucht einen Verweis aus Betrieb A auf eine Zeile in Betrieb B.
-- Drei Schichten duerfen abwehren, und es genuegt, dass EINE greift:
--   foreign_key_violation  - die Mandantenbindung aus 0008
--   restrict_violation     - die GoBD-Sperre aus 0010 (sieht seit security definer die Wahrheit)
--   insufficient_privilege - die Policy
-- Gelingt der Einfuegevorgang, schlaegt der Test fehl.
do $$
declare
  A uuid := 'aaaaaaaa-0000-0000-0000-00000000000a';
  fehlgeschlagen text[] := '{}';
begin
  -- 1. Position in fremde, festgeschriebene Rechnung
  begin
    insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
    values (A, 'b4000000-0000-0000-0000-00000000000b', 2, 'Eingeschmuggelt', 1, 99999);
    fehlgeschlagen := fehlgeschlagen || 'beleg_position -> fremder beleg';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 2. Eigener Beleg auf fremden Kunden
  begin
    insert into beleg (betrieb_id, kunde_id, art, erstellt_von)
    values (A, 'b1000000-0000-0000-0000-00000000000b', 'angebot', '11111111-1111-1111-1111-111111111111');
    fehlgeschlagen := fehlgeschlagen || 'beleg -> fremder kunde';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 3. Eigener Beleg auf fremdes Projekt
  begin
    insert into beleg (betrieb_id, kunde_id, projekt_id, art, erstellt_von)
    values (A, 'a1000000-0000-0000-0000-00000000000a', 'b2000000-0000-0000-0000-00000000000b', 'angebot', '11111111-1111-1111-1111-111111111111');
    fehlgeschlagen := fehlgeschlagen || 'beleg -> fremdes projekt';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 4. Eigener Beleg als Nachfolger eines fremden Belegs
  begin
    insert into beleg (betrieb_id, kunde_id, vorgaenger_id, art, erstellt_von)
    values (A, 'a1000000-0000-0000-0000-00000000000a', 'b4000000-0000-0000-0000-00000000000b', 'auftrag', '11111111-1111-1111-1111-111111111111');
    fehlgeschlagen := fehlgeschlagen || 'beleg -> fremder vorgaenger';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 5. Eigenes Projekt auf fremden Kunden
  begin
    insert into projekt (betrieb_id, kunde_id, bezeichnung)
    values (A, 'b1000000-0000-0000-0000-00000000000b', 'Fremdprojekt');
    fehlgeschlagen := fehlgeschlagen || 'projekt -> fremder kunde';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 6. Ansprechpartner an fremden Kunden
  begin
    insert into ansprechpartner (betrieb_id, kunde_id, name)
    values (A, 'b1000000-0000-0000-0000-00000000000b', 'Fremd');
    fehlgeschlagen := fehlgeschlagen || 'ansprechpartner -> fremder kunde';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 7. Eigener Artikel an fremden Lieferanten
  begin
    insert into artikel (betrieb_id, nummer, bezeichnung, lieferant_id)
    values (A, 'X-1', 'Artikel', 'b5000000-0000-0000-0000-00000000000b');
    fehlgeschlagen := fehlgeschlagen || 'artikel -> fremder lieferant';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 8. Dokumentation an fremdes Projekt
  begin
    insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von)
    values (gen_random_uuid(), A, 'b2000000-0000-0000-0000-00000000000b', 'notiz', 'Fremd', now(), 'a3000000-0000-0000-0000-00000000000a');
    fehlgeschlagen := fehlgeschlagen || 'dokumentation -> fremdes projekt';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 9. Zeiteintrag auf fremden Mitarbeiter
  begin
    insert into zeiteintrag (id, betrieb_id, mitarbeiter_id, beginn)
    values (gen_random_uuid(), A, 'b3000000-0000-0000-0000-00000000000b', now());
    fehlgeschlagen := fehlgeschlagen || 'zeiteintrag -> fremder mitarbeiter';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 10. Zeiteintrag abgerechnet ueber fremde Position
  begin
    insert into zeiteintrag (id, betrieb_id, mitarbeiter_id, beginn, position_id)
    values (gen_random_uuid(), A, 'a3000000-0000-0000-0000-00000000000a', now(), 'b6000000-0000-0000-0000-00000000000b');
    fehlgeschlagen := fehlgeschlagen || 'zeiteintrag -> fremde position';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 11. Einsatz mit fremdem Mitarbeiter
  begin
    insert into einsatz (betrieb_id, projekt_id, ressource_art, mitarbeiter_id, von, bis)
    values (A, 'a2000000-0000-0000-0000-00000000000a', 'mitarbeiter', 'b3000000-0000-0000-0000-00000000000b', now(), now() + interval '2 hours');
    fehlgeschlagen := fehlgeschlagen || 'einsatz -> fremder mitarbeiter';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  -- 12. Einsatz mit fremdem Subunternehmer
  begin
    insert into einsatz (betrieb_id, projekt_id, ressource_art, subunternehmer_id, von, bis)
    values (A, 'a2000000-0000-0000-0000-00000000000a', 'subunternehmer', 'b5000000-0000-0000-0000-00000000000b', now(), now() + interval '2 hours');
    fehlgeschlagen := fehlgeschlagen || 'einsatz -> fremder subunternehmer';
  exception when foreign_key_violation or insufficient_privilege or restrict_violation then null;
  end;

  if array_length(fehlgeschlagen, 1) > 0 then
    raise exception 'FAIL Mandantengrenze durchlaessig bei: %', array_to_string(fehlgeschlagen, ', ');
  end if;
end $$;

-- Brunos Rechnung ist unberuehrt geblieben.
reset role;
do $$
declare n integer; s numeric;
begin
  select count(*), coalesce(sum(gesamt),0) into n, s
    from beleg_position where beleg_id = 'b4000000-0000-0000-0000-00000000000b';
  if n <> 1 or s <> 8000.00 then
    raise exception 'FAIL Fremdrechnung veraendert: % Positionen, Summe %', n, s;
  end if;
end $$;

-- --------------------------------------------------- Deckung der Schluessel ---
-- Zusammengesetzte Fremdschluessel brauchen einen Index, der mit genau ihren
-- Spalten in genau ihrer Reihenfolge beginnt. Fehlt er, prueft Postgres jede
-- Elternaenderung mit einem Seq Scan je Kindtabelle - und betrieb_loeschen()
-- laeuft ueber alle Kindtabellen auf einmal.
--
-- Teilindizes zaehlen hier bewusst nicht als Deckung: sie enthalten nur die
-- Zeilen ihres Praedikats, die Pruefung fragt aber nach beliebigen. Der
-- Supabase-Lint ist an dieser Stelle nachsichtiger und meldet drei Schluessel
-- weniger, als tatsaechlich ungedeckt waren.
do $$
declare offen text[] := '{}';
begin
  select coalesce(array_agg(c.conrelid::regclass::text || '.' || c.conname order by c.conname), '{}')
    into offen
    from pg_constraint c
   where c.contype = 'f' and c.connamespace = 'public'::regnamespace
     and not exists (
       select 1
         from pg_index i
         join pg_class ic on ic.oid = i.indexrelid
        where i.indrelid = c.conrelid
          and i.indpred is null
          and ic.relam = (select oid from pg_am where amname = 'btree')
          and (i.indkey::smallint[])[0:cardinality(c.conkey) - 1] = c.conkey);
  if array_length(offen, 1) > 0 then
    raise exception 'FAIL Fremdschluessel ohne deckenden Index: %', array_to_string(offen, ', ');
  end if;
end $$;

-- Und keine zwei deckungsgleichen Indizes auf derselben Tabelle.
do $$
declare doppelt text[] := '{}';
begin
  select coalesce(array_agg(paar order by paar), '{}') into doppelt from (
    select i1.indrelid::regclass::text || ': ' ||
           i1.indexrelid::regclass::text || ' = ' || i2.indexrelid::regclass::text as paar
      from pg_index i1
      join pg_index i2
        on i1.indrelid = i2.indrelid
       and i1.indexrelid < i2.indexrelid
       and i1.indkey = i2.indkey
       and i1.indpred is not distinct from i2.indpred
       and i1.indexprs is not distinct from i2.indexprs
     where i1.indrelid in (select oid from pg_class
                            where relnamespace = 'public'::regnamespace and relkind = 'r')
  ) d;
  if array_length(doppelt, 1) > 0 then
    raise exception 'FAIL deckungsgleiche Indizes: %', array_to_string(doppelt, ', ');
  end if;
end $$;

\echo '  OK  Fremdreferenzen: 12 Wege versperrt, alle Fremdschluessel gedeckt, keine Doppelindizes'
