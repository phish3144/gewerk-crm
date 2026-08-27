-- Uebersicht und Fristen.
--
-- Geprueft wird, was auf der Startseite steht: offene Posten, Fristen und
-- Nachkalkulation. Jede Zahl muss aus Zeilen entstehen, die man aufklappen
-- kann - eine Kennzahl ohne Herkunft wird zu Recht ignoriert.

\set ON_ERROR_STOP on

insert into benutzer (id, email, anzeigename) values
  ('44440000-1111-0000-0000-000000000001', 'chefin@fristen.de', 'Chefin');
insert into betrieb (id, name) values
  ('44440000-0000-0000-0000-00000000000a', 'Fristenbetrieb');
insert into benutzer_betrieb values
  ('44440000-1111-0000-0000-000000000001', '44440000-0000-0000-0000-00000000000a', 'inhaber');
insert into kunde (id, betrieb_id, name, zahlungsziel_tage, skonto_prozent, skonto_tage) values
  ('44440000-2000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a',
   'Bauherr', 30, 2.00, 10);
insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('44440000-3000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a',
   '44440000-2000-0000-0000-00000000000a', 'Anbau Lindenweg');
insert into mitarbeiter (id, betrieb_id, name, stundensatz) values
  ('44440000-4000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a', 'Monteur', 50.00);
insert into lieferant (id, betrieb_id, name, ist_subunternehmer) values
  ('44440000-6000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a', 'Trockenbau Mueller', true);

set role authenticated;
set request.jwt.claim.sub = '44440000-1111-0000-0000-000000000001';

-- Auftrag mit Kalkulationsanteilen: 100 Stunden zu 60,00, davon 40,00 Lohn.
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von) values
  ('44440000-5000-0000-0000-000000000001', '44440000-0000-0000-0000-00000000000a',
   '44440000-2000-0000-0000-00000000000a', '44440000-3000-0000-0000-00000000000a',
   'auftrag', current_date, '44440000-1111-0000-0000-000000000001');
insert into beleg_position (betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit,
                            einzelpreis, lohn_anteil, material_anteil)
values ('44440000-0000-0000-0000-00000000000a', '44440000-5000-0000-0000-000000000001',
        1, 'lohn', 'Trockenbau', 100, 'Std', 60.00, 40.00, 5.00);
select beleg_festschreiben('44440000-5000-0000-0000-000000000001');

-- Rechnung, teilweise bezahlt: 7.140,00 brutto, 2.000,00 eingegangen.
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, datum, leistungsdatum, erstellt_von)
values ('44440000-5000-0000-0000-000000000002', '44440000-0000-0000-0000-00000000000a',
        '44440000-2000-0000-0000-00000000000a', '44440000-3000-0000-0000-00000000000a',
        'schlussrechnung', current_date - 5, current_date - 5,
        '44440000-1111-0000-0000-000000000001');
insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einheit, einzelpreis, steuersatz)
values ('44440000-0000-0000-0000-00000000000a', '44440000-5000-0000-0000-000000000002',
        1, 'Trockenbau Gesamtleistung', 100, 'Std', 60.00, 19);
select beleg_festschreiben('44440000-5000-0000-0000-000000000002');
insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                     steuersatz, steuerbetrag, art)
values ('44440000-0000-0000-0000-00000000000a', '44440000-5000-0000-0000-000000000002',
        current_date - 2, 2000.00, 1680.67, 19, 319.33, 'teilzahlung');

-- Tatsaechlich gearbeitet: 8 Stunden zu 50,00 Stundensatz = 400,00.
insert into dokumentation (id, betrieb_id, projekt_id, art, text, erfasst_am, erfasst_von) values
  ('44440000-7000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a',
   '44440000-3000-0000-0000-00000000000a', 'notiz', 'Nachweis', now(),
   '44440000-4000-0000-0000-00000000000a');
insert into zeiteintrag (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende, pause_minuten, nachweis_id)
values ('44440000-8000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a',
        '44440000-3000-0000-0000-00000000000a', '44440000-4000-0000-0000-00000000000a',
        now() - interval '8 hours', now(), 0, '44440000-7000-0000-0000-00000000000a');
-- Und Material fuer 250,00 entnommen.
insert into materialentnahme (id, betrieb_id, projekt_id, bezeichnung, menge, einheit, ek_preis,
                              erfasst_am, erfasst_von, nachweis_id)
values ('44440000-9000-0000-0000-00000000000a', '44440000-0000-0000-0000-00000000000a',
        '44440000-3000-0000-0000-00000000000a', 'Gipskarton', 100, 'Stk', 2.50, now(),
        '44440000-4000-0000-0000-00000000000a', '44440000-7000-0000-0000-00000000000a');

-- Abnahme vor zwei Jahren, VOB mit vier Jahren: noch zwei Jahre Frist.
insert into abnahme (betrieb_id, projekt_id, abgenommen_am, grundlage, erfasst_von)
values ('44440000-0000-0000-0000-00000000000a', '44440000-3000-0000-0000-00000000000a',
        current_date - interval '2 years', 'vob_4j', '44440000-1111-0000-0000-000000000001');

-- Freistellungsbescheinigung, laeuft in 20 Tagen ab.
insert into freistellungsbescheinigung (betrieb_id, lieferant_id, sicherheitsnummer, gueltig_bis, geprueft_am)
values ('44440000-0000-0000-0000-00000000000a', '44440000-6000-0000-0000-00000000000a',
        'DE1234567890', current_date + 20, current_date - 100);

-- Eine dritte Rechnung, mit Skonto beglichen: 1.190,00 brutto, davon 1.166,20
-- ueberwiesen und 23,80 Skonto gezogen. Zusammen ist sie damit ausgeglichen.
--
-- Ohne diesen Fall bliebe unbemerkt, dass die offenen Posten den Skontoanteil
-- mitzaehlen muessen - sonst stuende eine vollstaendig beglichene Rechnung
-- fuer immer als teilweise offen in der Liste und im Mahnlauf.
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, datum, leistungsdatum, erstellt_von)
values ('44440000-5000-0000-0000-000000000003', '44440000-0000-0000-0000-00000000000a',
        '44440000-2000-0000-0000-00000000000a', '44440000-3000-0000-0000-00000000000a',
        'teilrechnung', current_date - 20, current_date - 20,
        '44440000-1111-0000-0000-000000000001');
insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einheit, einzelpreis, steuersatz)
values ('44440000-0000-0000-0000-00000000000a', '44440000-5000-0000-0000-000000000003',
        1, 'Teilleistung Estrich', 1, 'Psch', 1000.00, 19);
select beleg_festschreiben('44440000-5000-0000-0000-000000000003');
insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                     steuersatz, steuerbetrag, art, skonto_brutto,
                     entgeltminderung_netto, ust_korrekturbetrag)
values ('44440000-0000-0000-0000-00000000000a', '44440000-5000-0000-0000-000000000003',
        current_date - 12, 1166.20, 980.00, 19, 186.20, 'teilzahlung',
        23.80, 20.00, 3.80);

-- ------------------------------------------------------- Offene Posten -----
do $$
declare o record;
begin
  select * into o from offene_posten where beleg_id = '44440000-5000-0000-0000-000000000002';
  if not found then
    raise exception 'FAIL die teilweise bezahlte Rechnung steht nicht in den offenen Posten';
  end if;
  -- 100 x 60,00 = 6.000,00 netto, 19 % = 1.140,00, brutto 7.140,00.
  -- Abzueglich 2.000,00 eingegangen bleiben 5.140,00 offen.
  if o.brutto <> 7140.00 or o.gezahlt <> 2000.00 or o.offen <> 5140.00 then
    raise exception 'FAIL offener Posten: brutto %, gezahlt %, offen %', o.brutto, o.gezahlt, o.offen;
  end if;
  if o.faelligkeit_am <> (current_date - 5) + 30 then
    raise exception 'FAIL Faelligkeit % statt %', o.faelligkeit_am, (current_date - 5) + 30;
  end if;
end $$;

-- Der Auftrag ist keine Forderung und darf nicht in den offenen Posten stehen.
do $$
begin
  if exists (select 1 from offene_posten where beleg_id = '44440000-5000-0000-0000-000000000001') then
    raise exception 'FAIL der Auftrag steht in den offenen Posten';
  end if;
end $$;

-- Und die mit Skonto beglichene Rechnung ebenfalls nicht: 1.166,20 ueberwiesen
-- plus 23,80 Skonto sind die vollen 1.190,00.
do $$
declare o record;
begin
  select * into o from offene_posten where beleg_id = '44440000-5000-0000-0000-000000000003';
  if found then
    raise exception
      'FAIL die mit Skonto beglichene Rechnung steht mit % noch offen - der Skontoanteil wird nicht mitgezaehlt',
      o.offen;
  end if;
end $$;

-- ----------------------------------------------------------- Fristen -------
do $$
declare f record; n integer;
begin
  select count(*) into n from fristen;
  -- Gewaehrleistung, Freistellungsbescheinigung, Skontofrist, Zahlungsziel.
  if n <> 4 then
    for f in select art, bezeichnung, faellig_am from fristen loop
      raise notice 'Frist: % / % / %', f.art, f.bezeichnung, f.faellig_am;
    end loop;
    raise exception 'FAIL % Fristen statt 4', n;
  end if;

  select * into f from fristen where art = 'gewaehrleistung';
  if f.faellig_am <> (current_date - interval '2 years' + interval '4 years')::date then
    raise exception 'FAIL Gewaehrleistung laeuft bis % statt in zwei Jahren', f.faellig_am;
  end if;
  if f.herkunft not like '%4 Jahre%' then
    raise exception 'FAIL die Herkunft nennt die Grundlage nicht: %', f.herkunft;
  end if;

  select * into f from fristen where art = 'freistellungsbescheinigung';
  if f.tage <> 20 then
    raise exception 'FAIL Freistellungsbescheinigung: % Tage statt 20', f.tage;
  end if;
  if f.herkunft not like '%DE1234567890%' then
    raise exception 'FAIL die Sicherheitsnummer fehlt in der Herkunft: %', f.herkunft;
  end if;

  -- 2 % von 5.140,00 = 102,80. Faellig 10 Tage nach Rechnungsdatum.
  select * into f from fristen where art = 'skontofrist';
  if f.betrag <> 102.80 then
    raise exception 'FAIL Skontobetrag % statt 102,80', f.betrag;
  end if;
  if f.faellig_am <> (current_date - 5) + 10 then
    raise exception 'FAIL Skontofrist % statt %', f.faellig_am, (current_date - 5) + 10;
  end if;

  select * into f from fristen where art = 'zahlungsziel';
  if f.betrag <> 5140.00 then
    raise exception 'FAIL Zahlungsziel steht bei % statt 5.140,00', f.betrag;
  end if;
end $$;

-- ------------------------------------------------------ Nachkalkulation ----
do $$
declare n record;
begin
  select * into n from nachkalkulation where projekt_id = '44440000-3000-0000-0000-00000000000a';

  -- Geplant: 100 Std x 60,00 = 6.000,00 Auftragssumme, davon 100 x 40,00 Lohn
  -- und 100 x 5,00 Material.
  if n.auftragssumme <> 6000.00 or n.lohn_geplant <> 4000.00 or n.material_geplant <> 500.00 then
    raise exception 'FAIL geplant: Summe %, Lohn %, Material %',
      n.auftragssumme, n.lohn_geplant, n.material_geplant;
  end if;

  -- Tatsaechlich: 8 Stunden zu 50,00 = 400,00 und 100 Stk zu 2,50 = 250,00.
  if n.stunden_ist <> 8.00 or n.lohn_ist <> 400.00 or n.material_ist <> 250.00 then
    raise exception 'FAIL tatsaechlich: Stunden %, Lohn %, Material %',
      n.stunden_ist, n.lohn_ist, n.material_ist;
  end if;
end $$;

-- --------------------------------------------- Mandantengrenze der Sichten --
-- Wie bei den Waechtersichten: ohne security_invoker liefert eine Sicht alle
-- Mandanten aus. Hier gegengeprueft mit einer Nutzerin ohne Zugehoerigkeit.
reset role;
insert into benutzer (id, email, anzeigename) values
  ('44440000-1111-0000-0000-000000000009', 'fremd@fristen.de', 'Fremde');
insert into betrieb (id, name) values ('44440000-0000-0000-0000-00000000000f', 'Fremdbetrieb');
insert into benutzer_betrieb values
  ('44440000-1111-0000-0000-000000000009', '44440000-0000-0000-0000-00000000000f', 'inhaber');

set role authenticated;
set request.jwt.claim.sub = '44440000-1111-0000-0000-000000000009';
do $$
declare n integer;
begin
  select count(*) into n from fristen;
  if n <> 0 then raise exception 'FAIL die Fristen zeigen % fremde Zeilen', n; end if;
  select count(*) into n from offene_posten;
  if n <> 0 then raise exception 'FAIL die offenen Posten zeigen % fremde Zeilen', n; end if;
  select count(*) into n from nachkalkulation;
  if n <> 0 then raise exception 'FAIL die Nachkalkulation zeigt % fremde Zeilen', n; end if;
end $$;
select betrieb_loeschen('44440000-0000-0000-0000-00000000000f');
reset role;

-- ----------------------------------------------------------- Aufraeumen -----
set role authenticated;
set request.jwt.claim.sub = '44440000-1111-0000-0000-000000000001';
select betrieb_loeschen('44440000-0000-0000-0000-00000000000a');
reset role;
delete from benutzer where id in ('44440000-1111-0000-0000-000000000001',
                                  '44440000-1111-0000-0000-000000000009');

\echo '  OK  Fristen: offene Posten, Gewaehrleistung, § 48b, Skonto, Zahlungsziel, Nachkalkulation, Mandantengrenze'
