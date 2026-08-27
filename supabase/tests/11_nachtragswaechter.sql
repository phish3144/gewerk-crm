-- Nachtragswaechter, Teil 1: Erkennen.
--
-- Geprueft wird an echten Zeilen, nicht am Katalog:
--   * Regel 1  Zeitbuchung ohne Position
--   * Regel 2  Materialentnahme ohne Position
--   * Regel 3  Ist ueber 110 % Soll, § 2 Abs. 3 Nr. 2 VOB/B
--   * die ehrliche Grenze von Regel 3: aus Stunden folgt keine Flaeche
--   * die Nachweispflicht bei "keine passende Position"
--   * der Eurobetrag gegen eine Handrechnung
--   * und der wichtigste Punkt: die Sichten halten die Mandantengrenze.
--     Eine Sicht laeuft in Postgres standardmaessig mit den Rechten ihrer
--     Eigentuemerin und umgeht damit jede Policy. Das ist die haeufigste
--     stille Datenlecke bei Supabase - hier wird sie ausgeschlossen.

\set ON_ERROR_STOP on

\set N   '''11110000-0000-0000-0000-00000000000n'''
\set F   '''ffff0000-0000-0000-0000-00000000000f'''

-- ---------------------------------------------------------------- Aufbau ----
insert into benutzer (id, email, anzeigename) values
  ('11110000-1111-0000-0000-000000000001', 'chef@waechter.de',  'Chefin'),
  ('11110000-1111-0000-0000-000000000002', 'fremd@waechter.de', 'Fremder');
insert into betrieb (id, name) values
  ('11110000-0000-0000-0000-00000000000a', 'Waechterbetrieb'),
  ('ffff0000-0000-0000-0000-00000000000f', 'Fremdbetrieb');
insert into benutzer_betrieb values
  ('11110000-1111-0000-0000-000000000001', '11110000-0000-0000-0000-00000000000a', 'inhaber'),
  ('11110000-1111-0000-0000-000000000002', 'ffff0000-0000-0000-0000-00000000000f', 'inhaber');

insert into kunde (id, betrieb_id, name) values
  ('11110000-2000-0000-0000-00000000000a', '11110000-0000-0000-0000-00000000000a', 'Bauherr'),
  ('ffff0000-2000-0000-0000-00000000000f', 'ffff0000-0000-0000-0000-00000000000f', 'Fremdkunde');
insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('11110000-3000-0000-0000-00000000000a', '11110000-0000-0000-0000-00000000000a',
   '11110000-2000-0000-0000-00000000000a', 'Neubau Musterweg'),
  ('ffff0000-3000-0000-0000-00000000000f', 'ffff0000-0000-0000-0000-00000000000f',
   'ffff0000-2000-0000-0000-00000000000f', 'Fremdbaustelle');
-- Stundensatz 55,00 - die Zahl, gegen die der Eurobetrag unten von Hand
-- nachgerechnet wird.
insert into mitarbeiter (id, betrieb_id, name, stundensatz) values
  ('11110000-4000-0000-0000-00000000000a', '11110000-0000-0000-0000-00000000000a', 'Monteur', 55.00),
  ('ffff0000-4000-0000-0000-00000000000f', 'ffff0000-0000-0000-0000-00000000000f', 'Fremdmonteur', 55.00);

-- Der Auftrag mit drei Positionen: eine in Stunden, eine in Metern, eine in
-- Quadratmetern. Die dritte ist der Fall, den Regel 3 NICHT beurteilen kann.
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von) values
  ('11110000-5000-0000-0000-00000000000a', '11110000-0000-0000-0000-00000000000a',
   '11110000-2000-0000-0000-00000000000a', '11110000-3000-0000-0000-00000000000a',
   'auftrag', current_date, '11110000-1111-0000-0000-000000000001');
insert into beleg_position
  (id, betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit, einzelpreis) values
  ('11110000-6000-0000-0000-000000000001', '11110000-0000-0000-0000-00000000000a',
   '11110000-5000-0000-0000-00000000000a', 1, 'lohn',     'Leitungen ziehen',  10, 'Std', 62.00),
  ('11110000-6000-0000-0000-000000000002', '11110000-0000-0000-0000-00000000000a',
   '11110000-5000-0000-0000-00000000000a', 2, 'material', 'Leerrohr M25',     100, 'm',    1.80),
  ('11110000-6000-0000-0000-000000000003', '11110000-0000-0000-0000-00000000000a',
   '11110000-5000-0000-0000-00000000000a', 3, 'leistung', 'Wand verputzen',   120, 'm²',  24.00);

-- Der Nachweis, den die Buchungen ohne Position mitbringen muessen.
insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von) values
  ('11110000-7000-0000-0000-00000000000a', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', 'notiz',
   'Bauherr wollte zusaetzlich eine Steckdose im Flur', now(),
   '11110000-4000-0000-0000-00000000000a');

-- ------------------------------------------------- Regel 1: Zeit ohne Pos ---
-- 4 Stunden minus 30 Minuten Pause = 3,5 Stunden.
insert into zeiteintrag
  (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende, pause_minuten, taetigkeit, nachweis_id)
values
  ('11110000-8000-0000-0000-000000000001', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', '11110000-4000-0000-0000-00000000000a',
   now() - interval '4 hours', now(), 30, 'Steckdose Flur nachgeruestet',
   '11110000-7000-0000-0000-00000000000a');

-- Beauftragte Stunden auf Position 1: zweimal 6 Stunden = 12 gegen Soll 10.
-- 12 > 11, also Mehrmenge nach Regel 3.
insert into zeiteintrag
  (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende, pause_minuten, position_id)
values
  ('11110000-8000-0000-0000-000000000002', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', '11110000-4000-0000-0000-00000000000a',
   now() - interval '6 hours', now(), 0, '11110000-6000-0000-0000-000000000001'),
  ('11110000-8000-0000-0000-000000000003', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', '11110000-4000-0000-0000-00000000000a',
   now() - interval '6 hours', now(), 0, '11110000-6000-0000-0000-000000000001');

-- Stunden auf die Quadratmeterposition. Beauftragt, also keine Meldung nach
-- Regel 1 - und aus Stunden folgt keine Flaeche, also auch keine nach Regel 3.
insert into zeiteintrag
  (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende, pause_minuten, position_id)
values
  ('11110000-8000-0000-0000-000000000004', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', '11110000-4000-0000-0000-00000000000a',
   now() - interval '9 hours', now(), 0, '11110000-6000-0000-0000-000000000003');

-- --------------------------------------------- Regel 2: Material ohne Pos ---
-- 12 Meter zu 2,50 = 30,00.
insert into materialentnahme
  (id, betrieb_id, projekt_id, bezeichnung, menge, einheit, ek_preis, erfasst_am, erfasst_von, nachweis_id)
values
  ('11110000-9000-0000-0000-000000000001', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', 'Leerrohr M25 zusaetzlich', 12, 'm', 2.50, now(),
   '11110000-4000-0000-0000-00000000000a', '11110000-7000-0000-0000-00000000000a');

-- Beauftragtes Material auf Position 2: 105 von 100 Metern. Das sind 105 %,
-- also unter der Schwelle - und darf gerade NICHT gemeldet werden.
insert into materialentnahme
  (id, betrieb_id, projekt_id, bezeichnung, menge, einheit, ek_preis, erfasst_am, erfasst_von, position_id)
values
  ('11110000-9000-0000-0000-000000000002', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', 'Leerrohr M25', 105, 'm', 1.20, now(),
   '11110000-4000-0000-0000-00000000000a', '11110000-6000-0000-0000-000000000002');

-- Der Fremdbetrieb bucht dasselbe. Nichts davon darf drueben auftauchen.
insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von) values
  ('ffff0000-7000-0000-0000-00000000000f', 'ffff0000-0000-0000-0000-00000000000f',
   'ffff0000-3000-0000-0000-00000000000f', 'notiz', 'Fremdnotiz', now(),
   'ffff0000-4000-0000-0000-00000000000f');
insert into zeiteintrag
  (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende, pause_minuten, taetigkeit, nachweis_id)
values
  ('ffff0000-8000-0000-0000-00000000000f', 'ffff0000-0000-0000-0000-00000000000f',
   'ffff0000-3000-0000-0000-00000000000f', 'ffff0000-4000-0000-0000-00000000000f',
   now() - interval '8 hours', now(), 0, 'Fremdarbeit',
   'ffff0000-7000-0000-0000-00000000000f');

-- ------------------------------------------------------ Nachweispflicht -----
-- Der Kern der Regel: ohne Position und ohne Nachweis geht es nicht. Nicht
-- "die Oberflaeche fragt nach" - die Datenbank laesst es nicht zu.
do $$
begin
  begin
    insert into zeiteintrag (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende)
    values (gen_random_uuid(), '11110000-0000-0000-0000-00000000000a',
            '11110000-3000-0000-0000-00000000000a', '11110000-4000-0000-0000-00000000000a',
            now() - interval '2 hours', now());
    raise exception 'FAIL Zeitbuchung ohne Position und ohne Nachweis war erlaubt';
  exception when check_violation then null;
  end;

  begin
    insert into materialentnahme (id, betrieb_id, projekt_id, bezeichnung, menge, einheit,
                                  ek_preis, erfasst_am, erfasst_von)
    values (gen_random_uuid(), '11110000-0000-0000-0000-00000000000a',
            '11110000-3000-0000-0000-00000000000a', 'Ohne Nachweis', 1, 'Stk', 10, now(),
            '11110000-4000-0000-0000-00000000000a');
    raise exception 'FAIL Materialentnahme ohne Position und ohne Nachweis war erlaubt';
  exception when check_violation then null;
  end;
end $$;

-- ------------------------------------------------ Die drei Regeln melden ----
set role authenticated;
set request.jwt.claim.sub = '11110000-1111-0000-0000-000000000001';

do $$
declare
  v_anzahl integer;
  v_summe  numeric;
  r        record;
  fehlt    text[] := '{}';
begin
  select count(*), coalesce(sum(betrag), 0) into v_anzahl, v_summe
    from ungeklaerte_leistung;

  -- Handrechnung:
  --   Regel 1   3,5 Std x 55,00 =  192,50
  --   Regel 2  12,0 m   x  2,50 =   30,00
  --   Regel 3   2,0 Std x 62,00 =  124,00   (12 statt 10 Stunden)
  --                               --------
  --                                 346,50
  if v_anzahl <> 3 then
    for r in select gegenstand, regel, bezeichnung, menge, betrag from ungeklaerte_leistung loop
      raise notice 'gemeldet: % / % / % / % / %', r.gegenstand, r.regel, r.bezeichnung, r.menge, r.betrag;
    end loop;
    raise exception 'FAIL % Meldungen statt 3', v_anzahl;
  end if;
  if v_summe <> 346.50 then
    raise exception 'FAIL Summe % statt 346,50 - der Eurobetrag ist die Botschaft', v_summe;
  end if;

  -- Jede Regel einzeln, damit ein Zufallstreffer der Summe nichts rettet.
  if not exists (select 1 from ungeklaerte_leistung
                  where gegenstand = 'zeiteintrag' and regel = 'ohne_position'
                    and menge = 3.50 and betrag = 192.50) then
    fehlt := fehlt || 'Regel 1 (Zeit ohne Position, 3,50 Std, 192,50)';
  end if;
  if not exists (select 1 from ungeklaerte_leistung
                  where gegenstand = 'materialentnahme' and regel = 'ohne_position'
                    and menge = 12 and betrag = 30.00) then
    fehlt := fehlt || 'Regel 2 (Material ohne Position, 12 m, 30,00)';
  end if;
  if not exists (select 1 from ungeklaerte_leistung
                  where gegenstand = 'position_mehrmenge' and regel = 'mehrmenge'
                    and gegenstand_id = '11110000-6000-0000-0000-000000000001'
                    and menge = 2 and betrag = 124.00 and betrag_vorlaeufig) then
    fehlt := fehlt || 'Regel 3 (Mehrmenge Position 1, 2 Std, 124,00, vorlaeufig)';
  end if;
  if array_length(fehlt, 1) > 0 then
    raise exception 'FAIL nicht gemeldet: %', array_to_string(fehlt, ', ');
  end if;
end $$;

-- ------------------------------------------------- Die beiden Nichtfaelle ---
do $$
begin
  -- 105 von 100 Metern sind 105 %. Unter der Schwelle, also keine Meldung.
  -- Zu viele Meldungen sind so schlecht wie keine.
  if exists (select 1 from ungeklaerte_leistung
              where gegenstand_id = '11110000-6000-0000-0000-000000000002') then
    raise exception 'FAIL 105 %% der Sollmenge wurden gemeldet - die Schwelle liegt bei 110 %%';
  end if;

  -- Die Quadratmeterposition: neun Stunden gebucht, aber aus Stunden folgt
  -- keine Flaeche. Lieber keine Zahl als eine erfundene.
  if exists (select 1 from ungeklaerte_leistung
              where gegenstand_id = '11110000-6000-0000-0000-000000000003') then
    raise exception 'FAIL eine Position in m² wurde aus Stunden beurteilt';
  end if;
  if (select ist_menge from leistungsstand
       where position_id = '11110000-6000-0000-0000-000000000003') is not null then
    raise exception 'FAIL der Leistungsstand einer m²-Position ist nicht NULL';
  end if;
end $$;

-- --------------------------------------------- Mandantengrenze der Sichten --
-- Der eigentlich gefaehrliche Punkt. Ohne security_invoker laeuft eine Sicht
-- mit den Rechten ihrer Eigentuemerin und liefert alle Mandanten aus.
do $$
declare v_fremd integer;
begin
  select count(*) into v_fremd from ungeklaerte_leistung
   where betrieb_id = 'ffff0000-0000-0000-0000-00000000000f';
  if v_fremd <> 0 then
    raise exception 'FAIL die Sicht ungeklaerte_leistung zeigt % fremde Zeilen', v_fremd;
  end if;

  select count(*) into v_fremd from leistungsstand
   where betrieb_id = 'ffff0000-0000-0000-0000-00000000000f';
  if v_fremd <> 0 then
    raise exception 'FAIL die Sicht leistungsstand zeigt % fremde Zeilen', v_fremd;
  end if;
end $$;

reset role;
set role authenticated;
set request.jwt.claim.sub = '11110000-1111-0000-0000-000000000002';
do $$
declare v_eigen integer;
begin
  -- Gegenprobe von der anderen Seite: der Fremde sieht seine eigene Meldung
  -- und ausschliesslich die.
  select count(*) into v_eigen from ungeklaerte_leistung;
  if v_eigen <> 1 then
    raise exception 'FAIL der Fremdbetrieb sieht % Meldungen statt genau seiner einen', v_eigen;
  end if;
end $$;
reset role;

-- ------------------------------------------------------------- Klaerung -----
set role authenticated;
set request.jwt.claim.sub = '11110000-1111-0000-0000-000000000001';

do $$
declare v_summe numeric;
begin
  insert into klaerung (betrieb_id, gegenstand, gegenstand_id, grund, geklaert_von)
  values ('11110000-0000-0000-0000-00000000000a', 'zeiteintrag',
          '11110000-8000-0000-0000-000000000001',
          'Kulanz - der Bauherr hat den Auftrag im gleichen Zug erweitert',
          '11110000-1111-0000-0000-000000000001');

  select coalesce(sum(betrag), 0) into v_summe from ungeklaerte_leistung;
  if v_summe <> 154.00 then
    raise exception 'FAIL nach der Klaerung stehen % statt 154,00 offen', v_summe;
  end if;
end $$;

-- Die Begruendung ist der Wert. Sie muss im Journal stehen, sonst ist sie in
-- sechs Monaten nicht mehr auffindbar.
reset role;
do $$
declare v_grund text;
begin
  select nachher ->> 'grund' into v_grund
    from journal
   where tabelle = 'klaerung' and aktion = 'insert'
     and betrieb_id = '11110000-0000-0000-0000-00000000000a'
   order by id desc limit 1;
  if v_grund is null or v_grund not like 'Kulanz%' then
    raise exception 'FAIL die Klaerungsbegruendung steht nicht im Journal (%)', coalesce(v_grund, 'nichts');
  end if;
end $$;

-- ------------------------------- Ein gebuchter Artikel bleibt loeschbar -----
-- Die Entnahme traegt Bezeichnung und Einkaufspreis selbst (0022). Deshalb
-- darf der Stammsatz verschwinden, ohne dass die Buchung dabei ihre Benennung
-- verliert - vor 0022 scheiterte das Loeschen an einer Pruefregel auf
-- materialentnahme, und der Artikel war fuer immer unloeschbar.
reset role;
insert into artikel (id, betrieb_id, nummer, bezeichnung, einheit, ek_preis) values
  ('11110000-a000-0000-0000-00000000000a', '11110000-0000-0000-0000-00000000000a',
   'ART-WEG', 'Schelle 32 mm', 'Stk', 0.85);
insert into materialentnahme
  (id, betrieb_id, projekt_id, artikel_id, bezeichnung, menge, einheit, ek_preis,
   erfasst_am, erfasst_von, nachweis_id)
values
  ('11110000-9000-0000-0000-000000000003', '11110000-0000-0000-0000-00000000000a',
   '11110000-3000-0000-0000-00000000000a', '11110000-a000-0000-0000-00000000000a',
   'Schelle 32 mm', 20, 'Stk', 0.85, now(),
   '11110000-4000-0000-0000-00000000000a', '11110000-7000-0000-0000-00000000000a');

do $$
declare v_bez text; v_artikel uuid;
begin
  delete from artikel where id = '11110000-a000-0000-0000-00000000000a';

  select bezeichnung, artikel_id into v_bez, v_artikel
    from materialentnahme where id = '11110000-9000-0000-0000-000000000003';
  if v_bez <> 'Schelle 32 mm' then
    raise exception 'FAIL die Entnahme hat ihre Bezeichnung verloren: %', coalesce(v_bez, 'NULL');
  end if;
  if v_artikel is not null then
    raise exception 'FAIL der Verweis auf den geloeschten Artikel steht noch';
  end if;
end $$;

delete from materialentnahme where id = '11110000-9000-0000-0000-000000000003';
set role authenticated;
set request.jwt.claim.sub = '11110000-1111-0000-0000-000000000001';

-- --------------------------------------------------- Der Nachweis bleibt ----
-- Solange eine Buchung ohne Position ihren Nachweis braucht, laesst er sich
-- nicht loeschen. Geprueft wird beides: dass es scheitert, und dass es mit der
-- richtigen Begruendung scheitert - vor 0021 kam hier eine Meldung ueber eine
-- Pruefregel auf zeiteintrag, und wer eine Notiz loeschen wollte, suchte den
-- Fehler an der falschen Stelle.
do $$
declare v_meldung text; v_zustand text;
begin
  begin
    delete from dokumentation where id = '11110000-7000-0000-0000-00000000000a';
    raise exception 'FAIL der Nachweis liess sich loeschen, obwohl Buchungen ihn brauchen';
  exception when others then
    get stacked diagnostics v_meldung = message_text, v_zustand = returned_sqlstate;
    if v_zustand <> '23503' then
      raise exception 'FAIL erwartet war eine Fremdschluesselverletzung (23503), gekommen ist % (%)',
        v_zustand, v_meldung;
    end if;
  end;
end $$;

do $$
declare n integer;
begin
  select count(*) into n from dokumentation where id = '11110000-7000-0000-0000-00000000000a';
  if n <> 1 then
    raise exception 'FAIL der Nachweis ist nach dem Loeschversuch weg';
  end if;
end $$;

-- ----------------------------------------------------------- Aufraeumen -----
-- Zugleich eine Zusicherung: seit 0021 steht auf nachweis_id ein RESTRICT.
-- Die Mandantenloeschung raeumt Nachweise und Buchungen in einer Kaskade ab und
-- darf daran nicht haengenbleiben - sonst waere ein Betrieb nicht mehr
-- loeschbar, und das ist keine Kleinigkeit, sondern eine DSGVO-Zusage.
set role authenticated;
set request.jwt.claim.sub = '11110000-1111-0000-0000-000000000001';
select betrieb_loeschen('11110000-0000-0000-0000-00000000000a');
reset role;
set role authenticated;
set request.jwt.claim.sub = '11110000-1111-0000-0000-000000000002';
select betrieb_loeschen('ffff0000-0000-0000-0000-00000000000f');
reset role;
delete from benutzer where id in ('11110000-1111-0000-0000-000000000001',
                                 '11110000-1111-0000-0000-000000000002');

\echo '  OK  Nachtragswaechter: drei Regeln, zwei Nichtfaelle, Nachweispflicht, Eurobetrag, Mandantengrenze, Nachweis bleibt, Artikel loeschbar'
