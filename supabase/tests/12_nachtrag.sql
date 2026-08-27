-- Nachtragswaechter, Teil 2: Handeln.
--
-- Der Weg von der Meldung zum abrechenbaren Nachtrag, an echten Zeilen:
--   * aus zwei Meldungen wird ein Nachtragsentwurf mit zwei Positionen
--   * die Buchungen haengen danach an den neuen Positionen und sind aus
--     "ungeklaert" verschwunden
--   * der Bezug auf den Hauptauftrag steht in vorgaenger_id
--   * ohne Preis laesst sich der Nachtrag nicht festschreiben - ab 110 % zaehlen
--     die tatsaechlich erforderlichen Kosten, nicht der alte Einheitspreis
--   * festgeschrieben traegt er eine NA-Nummer und zaehlt im Leistungsstand mit
--   * die Bedenkenanzeige ist nach dem Versand weder aenderbar noch loeschbar

\set ON_ERROR_STOP on

insert into benutzer (id, email, anzeigename) values
  ('22220000-1111-0000-0000-000000000001', 'chefin@nachtrag.de', 'Chefin');
insert into betrieb (id, name) values
  ('22220000-0000-0000-0000-00000000000a', 'Nachtragsbetrieb');
insert into benutzer_betrieb values
  ('22220000-1111-0000-0000-000000000001', '22220000-0000-0000-0000-00000000000a', 'inhaber');
insert into kunde (id, betrieb_id, name) values
  ('22220000-2000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a', 'Bauherr');
insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('22220000-3000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a',
   '22220000-2000-0000-0000-00000000000a', 'Umbau Hofgasse');
insert into mitarbeiter (id, betrieb_id, name, stundensatz) values
  ('22220000-4000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a', 'Monteur', 55.00);

-- Der Hauptauftrag, festgeschrieben - er ist der Bezug des Nachtrags.
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von) values
  ('22220000-5000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a',
   '22220000-2000-0000-0000-00000000000a', '22220000-3000-0000-0000-00000000000a',
   'auftrag', current_date, '22220000-1111-0000-0000-000000000001');
insert into beleg_position (id, betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit, einzelpreis) values
  ('22220000-6000-0000-0000-000000000001', '22220000-0000-0000-0000-00000000000a',
   '22220000-5000-0000-0000-00000000000a', 1, 'lohn', 'Elektroinstallation', 40, 'Std', 62.00);

set role authenticated;
set request.jwt.claim.sub = '22220000-1111-0000-0000-000000000001';
select beleg_festschreiben('22220000-5000-0000-0000-00000000000a');
reset role;

-- Zwei ungeklaerte Buchungen: vier Stunden und zwanzig Meter Kabel.
insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von) values
  ('22220000-7000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a',
   '22220000-3000-0000-0000-00000000000a', 'notiz',
   'Bauherr wollte den Zaehlerschrank versetzen', now(), '22220000-4000-0000-0000-00000000000a');

insert into zeiteintrag (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende,
                         pause_minuten, taetigkeit, nachweis_id) values
  ('22220000-8000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a',
   '22220000-3000-0000-0000-00000000000a', '22220000-4000-0000-0000-00000000000a',
   now() - interval '4 hours', now(), 0, 'Zaehlerschrank versetzt',
   '22220000-7000-0000-0000-00000000000a');

insert into materialentnahme (id, betrieb_id, projekt_id, bezeichnung, menge, einheit, ek_preis,
                              erfasst_am, erfasst_von, nachweis_id) values
  ('22220000-9000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a',
   '22220000-3000-0000-0000-00000000000a', 'NYM-J 5x2,5', 20, 'm', 3.10, now(),
   '22220000-4000-0000-0000-00000000000a', '22220000-7000-0000-0000-00000000000a');

-- ------------------------------------------------------ Meldung -> Nachtrag --
set role authenticated;
set request.jwt.claim.sub = '22220000-1111-0000-0000-000000000001';

do $$
declare n integer; s numeric;
begin
  select count(*), coalesce(sum(betrag), 0) into n, s from ungeklaerte_leistung;
  -- 4 Std x 55,00 = 220,00 und 20 m x 3,10 = 62,00 ergeben 282,00.
  if n <> 2 or s <> 282.00 then
    raise exception 'FAIL Testaufbau: % Meldungen ueber % statt 2 ueber 282,00', n, s;
  end if;
end $$;

-- Ueber set_config statt \gset: psql ersetzt seine eigenen Variablen nicht
-- innerhalb von $-Bloecken, und genau dort wird der Wert gebraucht. Der dritte
-- Parameter false macht die Einstellung sitzungsweit statt transaktionsweit.
select set_config('test.nachtrag', nachtrag_anlegen(
  '22220000-3000-0000-0000-00000000000a',
  jsonb_build_array(
    jsonb_build_object('gegenstand', 'zeiteintrag',
                       'gegenstand_id', '22220000-8000-0000-0000-00000000000a'),
    jsonb_build_object('gegenstand', 'materialentnahme',
                       'gegenstand_id', '22220000-9000-0000-0000-00000000000a')
  )
)::text, false);

do $$
declare
  v_nachtrag uuid := current_setting('test.nachtrag')::uuid;
  v_beleg    record;
  n          integer;
begin
  select * into v_beleg from beleg where id = v_nachtrag;
  if v_beleg.art <> 'nachtrag' then
    raise exception 'FAIL der erzeugte Beleg ist ein %', v_beleg.art;
  end if;
  if v_beleg.vorgaenger_id <> '22220000-5000-0000-0000-00000000000a' then
    raise exception 'FAIL der Bezug auf den Hauptauftrag fehlt';
  end if;
  if v_beleg.status <> 'entwurf' then
    raise exception 'FAIL der Nachtrag entsteht nicht als Entwurf, sondern als %', v_beleg.status;
  end if;

  select count(*) into n from beleg_position where beleg_id = v_nachtrag;
  if n <> 2 then
    raise exception 'FAIL % Nachtragspositionen statt 2', n;
  end if;

  -- Die Mengen kommen aus dem Ist, die Preise sind ausdruecklich leer.
  if not exists (select 1 from beleg_position
                  where beleg_id = v_nachtrag and bezeichnung = 'Zaehlerschrank versetzt'
                    and menge = 4 and einheit = 'Std' and einzelpreis = 0) then
    raise exception 'FAIL die Zeitposition steht nicht mit 4 Std und ohne Preis da';
  end if;
  if not exists (select 1 from beleg_position
                  where beleg_id = v_nachtrag and bezeichnung = 'NYM-J 5x2,5'
                    and menge = 20 and einheit = 'm' and art = 'material' and einzelpreis = 0) then
    raise exception 'FAIL die Materialposition stimmt nicht';
  end if;

  -- Und die Buchungen haengen jetzt daran.
  if (select position_id from zeiteintrag where id = '22220000-8000-0000-0000-00000000000a') is null then
    raise exception 'FAIL die Zeitbuchung haengt nach dem Nachtrag an keiner Position';
  end if;
  if (select position_id from materialentnahme where id = '22220000-9000-0000-0000-00000000000a') is null then
    raise exception 'FAIL die Materialentnahme haengt nach dem Nachtrag an keiner Position';
  end if;

  select count(*) into n from ungeklaerte_leistung;
  if n <> 0 then
    raise exception 'FAIL nach dem Nachtrag stehen noch % Meldungen offen', n;
  end if;

  -- Der Klaerungsvermerk zeigt auf den Nachtrag: "im Nachtrag NA-...".
  select count(*) into n from klaerung where nachtrag_id = v_nachtrag;
  if n <> 2 then
    raise exception 'FAIL % Klaerungsvermerke mit Nachtragsbezug statt 2', n;
  end if;
end $$;

-- ------------------------------------------------------------ Preispflicht --
do $$
declare v_nachtrag uuid := current_setting('test.nachtrag')::uuid;
begin
  begin
    perform beleg_festschreiben(v_nachtrag);
    raise exception 'FAIL der Nachtrag liess sich ohne Preise festschreiben';
  exception when restrict_violation then null;
  end;
end $$;

-- Die tatsaechlich erforderlichen Kosten eintragen, dann geht es.
update beleg_position set einzelpreis = 68.00
 where beleg_id = current_setting('test.nachtrag')::uuid and einheit = 'Std';
update beleg_position set einzelpreis = 4.80
 where beleg_id = current_setting('test.nachtrag')::uuid and einheit = 'm';

do $$
declare
  v_nachtrag uuid := current_setting('test.nachtrag')::uuid;
  v_nummer   text;
  v_beleg    record;
begin
  v_nummer := beleg_festschreiben(v_nachtrag);
  if v_nummer not like 'NA-%' then
    raise exception 'FAIL die Nachtragsnummer lautet % statt NA-...', v_nummer;
  end if;

  select * into v_beleg from beleg where id = v_nachtrag;
  -- 4 x 68,00 = 272,00 und 20 x 4,80 = 96,00 ergeben 368,00 netto.
  if v_beleg.netto <> 368.00 then
    raise exception 'FAIL der Nachtrag steht bei % statt 368,00 netto', v_beleg.netto;
  end if;
end $$;

-- ------------------------------------------------- Nachtrag zaehlt als Soll --
-- Waere das nicht so, meldete der Waechter die Mehrmenge, die er selbst gerade
-- zum Nachtrag gemacht hat, sofort wieder.
do $$
declare n integer;
begin
  select count(*) into n from leistungsstand
   where beleg_id = current_setting('test.nachtrag')::uuid;
  if n <> 2 then
    raise exception 'FAIL % Nachtragspositionen im Leistungsstand statt 2', n;
  end if;

  if (select ist_menge from leistungsstand
       where beleg_id = current_setting('test.nachtrag')::uuid and einheit = 'Std') <> 4 then
    raise exception 'FAIL die gebuchten Stunden zaehlen nicht auf die Nachtragsposition';
  end if;

  select count(*) into n from ungeklaerte_leistung;
  if n <> 0 then
    raise exception 'FAIL der festgeschriebene Nachtrag erzeugt % neue Meldungen', n;
  end if;
end $$;

-- --------------------------------------------------------- Bedenkenanzeige --
insert into bedenkenanzeige (id, betrieb_id, projekt_id, nachtrag_id, betreff, sachverhalt,
                             folgen, erstellt_von)
values ('22220000-b000-0000-0000-00000000000a', '22220000-0000-0000-0000-00000000000a',
        '22220000-3000-0000-0000-00000000000a', current_setting('test.nachtrag')::uuid,
        'Zaehlerschrank an der vorgesehenen Stelle nicht zulaessig',
        'Der geplante Standort unterschreitet den Mindestabstand zur Gasleitung.',
        'Ohne Verlegung ist die Abnahme durch den Netzbetreiber nicht zu erwarten.',
        '22220000-1111-0000-0000-000000000001');
insert into bedenken_nachweis (betrieb_id, bedenkenanzeige_id, dokumentation_id) values
  ('22220000-0000-0000-0000-00000000000a', '22220000-b000-0000-0000-00000000000a',
   '22220000-7000-0000-0000-00000000000a');

-- Solange sie Entwurf ist, darf sie sich bewegen.
update bedenkenanzeige set sachverhalt = sachverhalt || ' Nachgemessen am Vortag.'
 where id = '22220000-b000-0000-0000-00000000000a';

-- Halber Versand ist kein Versand.
do $$
begin
  begin
    update bedenkenanzeige set versendet_am = now()
     where id = '22220000-b000-0000-0000-00000000000a';
    raise exception 'FAIL Versand ohne Weg und Empfaenger war erlaubt';
  exception when check_violation then null;
  end;
end $$;

update bedenkenanzeige
   set versendet_am = now(), versendet_wie = 'E-Mail mit Lesebestaetigung',
       versendet_an = 'bauleitung@bauherr.example'
 where id = '22220000-b000-0000-0000-00000000000a';

-- Ab jetzt eingefroren. Eine nachtraeglich praezisierte Bedenkenanzeige ist im
-- Streitfall wertlos - ihr ganzer Wert liegt im belegbaren Zeitpunkt.
do $$
begin
  begin
    update bedenkenanzeige set sachverhalt = 'Etwas ganz anderes'
     where id = '22220000-b000-0000-0000-00000000000a';
    raise exception 'FAIL die versendete Bedenkenanzeige liess sich aendern';
  exception when restrict_violation then null;
  end;

  begin
    update bedenkenanzeige set versendet_an = 'jemand.anderes@example'
     where id = '22220000-b000-0000-0000-00000000000a';
    raise exception 'FAIL der Empfaenger liess sich nachtraeglich austauschen';
  exception when restrict_violation then null;
  end;

  begin
    delete from bedenkenanzeige where id = '22220000-b000-0000-0000-00000000000a';
    raise exception 'FAIL die versendete Bedenkenanzeige liess sich loeschen';
  exception when restrict_violation then null;
  end;
end $$;

do $$
declare v_text text;
begin
  select sachverhalt into v_text from bedenkenanzeige
   where id = '22220000-b000-0000-0000-00000000000a';
  if v_text not like '%Mindestabstand zur Gasleitung%' then
    raise exception 'FAIL der Sachverhalt ist nicht mehr der von damals: %', v_text;
  end if;
end $$;

-- ----------------------------------------------------------- Aufraeumen -----
select betrieb_loeschen('22220000-0000-0000-0000-00000000000a');
reset role;
delete from benutzer where id = '22220000-1111-0000-0000-000000000001';

\echo '  OK  Nachtrag: Meldung wird Position, Preispflicht nach BGH, NA-Nummer, Leistungsstand, Bedenkenanzeige eingefroren'
