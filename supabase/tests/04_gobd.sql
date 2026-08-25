-- GoBD-Unveraenderbarkeit, Nummernkreis und Journal.
-- Deckt die Befunde ab, die die adversariale Pruefung als ungetestet benannt hat:
-- Unveraenderbarkeit wurde nur an netto und nummer geprueft, das Journal nur auf
-- Neuanlagen, der Nummernkreis nur gegen UPDATE.
\set ON_ERROR_STOP on
\set QUIET on

reset role;
truncate betrieb, benutzer cascade;
-- Das Journal wird NICHT geleert: es ist anfuegend (0011). Aussagen darueber
-- grenzen sich stattdessen auf den Mandanten dieses Tests ein.

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@a.de', 'Anna');
insert into betrieb (id, name) values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'Betrieb A');
insert into benutzer_betrieb values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-00000000000a', 'inhaber');
insert into kunde (id, betrieb_id, name, strasse, plz, ort, ust_id, zahlungsziel_tage) values
  ('a1000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a',
   'Stadt Musterhausen', 'Rathausplatz 1', '12345', 'Musterhausen', 'DE123456789', 14);

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

insert into beleg (id, betrieb_id, kunde_id, art, leistungsdatum, betreff, erstellt_von) values
  ('a4000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a',
   'a1000000-0000-0000-0000-00000000000a', 'schlussrechnung', current_date, 'Kita Ahornweg',
   '11111111-1111-1111-1111-111111111111');
insert into beleg_position (id, betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis) values
  ('a6000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a',
   'a4000000-0000-0000-0000-00000000000a', 1, 'Leerrohr M25', 420, 7.80);

-- Entwurf: Summen muessen aus den Positionen kommen. 420 x 7,80 = 3.276,00
do $$
declare n numeric; s numeric; b numeric;
begin
  select netto, steuer, brutto into n, s, b from beleg where id = 'a4000000-0000-0000-0000-00000000000a';
  if n <> 3276.00 or s <> 622.44 or b <> 3898.44 then
    raise exception 'FAIL Summen im Entwurf: netto % steuer % brutto % (erwartet 3276.00 / 622.44 / 3898.44)', n, s, b;
  end if;
end $$;

select beleg_festschreiben('a4000000-0000-0000-0000-00000000000a') \gset nr_

-- Nummer traegt die Belegart im Praefix, damit sie betriebsweit eindeutig ist.
do $$
declare v text;
begin
  select nummer into v from beleg where id = 'a4000000-0000-0000-0000-00000000000a';
  if v not like 'RE-%' then
    raise exception 'FAIL Rechnungsnummer ohne Artkennung: %', v;
  end if;
end $$;

-- Kundendaten sind zum Zeitpunkt der Festschreibung eingefroren.
do $$
declare v text;
begin
  select kunde_name into v from beleg where id = 'a4000000-0000-0000-0000-00000000000a';
  if v is distinct from 'Stadt Musterhausen' then
    raise exception 'FAIL Kundenkopie fehlt: %', v;
  end if;
end $$;

-- --------------------------------------------------- Unveraenderbarkeit ------
do $$
declare
  B uuid := 'a4000000-0000-0000-0000-00000000000a';
  durchgelassen text[] := '{}';
begin
  begin update beleg set netto = 1 where id = B;
        durchgelassen := array_append(durchgelassen, 'netto'); exception when restrict_violation then null; end;
  begin update beleg set nummer = 'GEFAELSCHT' where id = B;
        durchgelassen := array_append(durchgelassen, 'nummer'); exception when restrict_violation then null; end;
  begin update beleg set datum = current_date - 30 where id = B;
        durchgelassen := array_append(durchgelassen, 'datum'); exception when restrict_violation then null; end;
  begin update beleg set leistungsdatum = current_date - 30 where id = B;
        durchgelassen := array_append(durchgelassen, 'leistungsdatum'); exception when restrict_violation then null; end;
  begin update beleg set betreff = 'anders' where id = B;
        durchgelassen := array_append(durchgelassen, 'betreff'); exception when restrict_violation then null; end;
  begin update beleg set kunde_name = 'Andere Firma' where id = B;
        durchgelassen := array_append(durchgelassen, 'kunde_name'); exception when restrict_violation then null; end;
  begin update beleg set kunde_ust_id = 'DE999' where id = B;
        durchgelassen := array_append(durchgelassen, 'kunde_ust_id'); exception when restrict_violation then null; end;
  begin update beleg set zahlungsziel_tage = 90 where id = B;
        durchgelassen := array_append(durchgelassen, 'zahlungsziel'); exception when restrict_violation then null; end;
  begin update beleg set festgeschrieben_am = now() - interval '10 days' where id = B;
        durchgelassen := array_append(durchgelassen, 'festgeschrieben_am'); exception when restrict_violation then null; end;
  -- Der Weg zurueck in den Entwurf war voellig offen: danach war alles wieder aenderbar.
  begin update beleg set status = 'entwurf' where id = B;
        durchgelassen := array_append(durchgelassen, 'status zurueck auf entwurf'); exception when restrict_violation then null; end;
  -- Storno ohne Verweis auf den Stornobeleg.
  begin update beleg set status = 'storniert' where id = B;
        durchgelassen := array_append(durchgelassen, 'storniert ohne Verweis'); exception when restrict_violation then null; end;
  begin delete from beleg where id = B;
        durchgelassen := array_append(durchgelassen, 'geloescht'); exception when restrict_violation then null; end;

  if array_length(durchgelassen, 1) > 0 then
    raise exception 'FAIL festgeschriebener Beleg aenderbar bei: %', array_to_string(durchgelassen, ', ');
  end if;
end $$;

-- Positionen des festgeschriebenen Belegs
do $$
declare
  B uuid := 'a4000000-0000-0000-0000-00000000000a';
  P uuid := 'a6000000-0000-0000-0000-00000000000a';
  durchgelassen text[] := '{}';
  E uuid;
begin
  begin insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
        values ('aaaaaaaa-0000-0000-0000-00000000000a', B, 2, 'Nachtraeglich', 1, 500);
        durchgelassen := array_append(durchgelassen, 'Position eingefuegt'); exception when restrict_violation then null; end;
  begin update beleg_position set einzelpreis = 99 where id = P;
        durchgelassen := array_append(durchgelassen, 'Position geaendert'); exception when restrict_violation then null; end;
  begin delete from beleg_position where id = P;
        durchgelassen := array_append(durchgelassen, 'Position geloescht'); exception when restrict_violation then null; end;

  -- Position aus der festgeschriebenen Rechnung in einen Entwurf umhaengen.
  -- Der alte Trigger pruefte nur den ZIEL-Beleg und liess das durch.
  insert into beleg (id, betrieb_id, kunde_id, art, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'angebot',
          '11111111-1111-1111-1111-111111111111')
  returning id into E;
  begin update beleg_position set beleg_id = E where id = P;
        durchgelassen := array_append(durchgelassen, 'Position herausgezogen'); exception when restrict_violation then null; end;

  if array_length(durchgelassen, 1) > 0 then
    raise exception 'FAIL Positionen aenderbar bei: %', array_to_string(durchgelassen, ', ');
  end if;
end $$;

-- ------------------------------------------------------- Nummernkreis --------
do $$
declare durchgelassen text[] := '{}';
begin
  begin update nummernkreis set naechste = 1;
        durchgelassen := array_append(durchgelassen, 'update'); exception when insufficient_privilege then null; end;
  begin delete from nummernkreis;
        durchgelassen := array_append(durchgelassen, 'delete'); exception when insufficient_privilege then null; end;
  begin insert into nummernkreis (betrieb_id, art, jahr, naechste)
        values ('aaaaaaaa-0000-0000-0000-00000000000a', 'gutschrift', 2026, 1);
        durchgelassen := array_append(durchgelassen, 'insert'); exception when insufficient_privilege then null; end;
  begin perform naechste_nummer('aaaaaaaa-0000-0000-0000-00000000000a', 'angebot', 2026::smallint);
        durchgelassen := array_append(durchgelassen, 'naechste_nummer direkt'); exception when insufficient_privilege then null; end;

  if array_length(durchgelassen, 1) > 0 then
    raise exception 'FAIL Nummernkreis beschreibbar bei: %', array_to_string(durchgelassen, ', ');
  end if;
end $$;

-- Nummern sind betriebsweit eindeutig, nicht nur je Belegart.
do $$
declare a uuid; r text; g text;
begin
  insert into beleg (betrieb_id, kunde_id, art, erstellt_von)
  values ('aaaaaaaa-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-00000000000a','angebot',
          '11111111-1111-1111-1111-111111111111') returning id into a;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', a, 1, 'Angebotsposition', 1, 100);
  r := beleg_festschreiben(a);
  select nummer into g from beleg where id = 'a4000000-0000-0000-0000-00000000000a';
  if r = g then
    raise exception 'FAIL Angebot und Rechnung tragen dieselbe Nummer: %', r;
  end if;
  if r not like 'AN-%' then
    raise exception 'FAIL Angebotsnummer ohne Artkennung: %', r;
  end if;
end $$;

-- ------------------------------------------------------------ Journal --------
-- Geprueft werden alle drei Aktionen, nicht nur insert.
reset role;
do $$
declare i integer; u integer; d integer;
begin
  select count(*) filter (where aktion = 'insert'),
         count(*) filter (where aktion = 'update'),
         count(*) filter (where aktion = 'delete')
    into i, u, d
    from journal
     where tabelle in ('beleg', 'beleg_position')
       and betrieb_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  if i = 0 then raise exception 'FAIL Journal ohne insert-Eintraege'; end if;
  if u = 0 then raise exception 'FAIL Journal ohne update-Eintraege (Festschreibung fehlt)'; end if;
end $$;

-- Das Journal ist anfuegend: auch der Eigentuemer darf nicht aendern oder loeschen.
do $$
declare durchgelassen text[] := '{}';
begin
  begin update journal set aktion = 'insert' where true;
        durchgelassen := array_append(durchgelassen, 'update');
        exception when insufficient_privilege or restrict_violation then null; end;
  begin delete from journal where true;
        durchgelassen := array_append(durchgelassen, 'delete');
        exception when insufficient_privilege or restrict_violation then null; end;
  begin truncate journal;
        durchgelassen := array_append(durchgelassen, 'truncate');
        exception when insufficient_privilege or restrict_violation then null; end;
  if array_length(durchgelassen, 1) > 0 then
    raise exception 'FAIL Journal veraenderbar bei: %', array_to_string(durchgelassen, ', ');
  end if;
end $$;

\echo '  OK  GoBD: Unveraenderbarkeit, Nummernkreis und Journal halten'
