-- Demodaten für einen Sanitär-, Heizungs- und Klimabetrieb.
--
-- Läuft als `postgres` gegen ein Projekt und füllt EINEN vorhandenen Betrieb.
-- Vorher setzen:
--
--   \set betrieb  '<uuid des betriebs>'
--   \set inhaber  '<uuid des inhabers>'
--
-- Das Festschreiben läuft über beleg_festschreiben() und damit über denselben
-- Weg wie in der Anwendung: Nummernkreis, Prüfungen, Journal. Dafür braucht die
-- Funktion auth.uid(), deshalb wird der Anspruch hier gesetzt.
--
-- Wiederholbar: der Block am Ende räumt vorher alles ab, was dieses Skript
-- angelegt hat. Festgeschriebene Belege lassen sich nicht löschen — deshalb
-- wird beim zweiten Lauf ein neuer Jahrgang von Nummern vergeben, nicht
-- derselbe.

select set_config('request.jwt.claims',
  json_build_object('sub', :'inhaber', 'email', 'demo@gewerk.local')::text, false);

-- psql ersetzt seine eigenen Variablen nicht innerhalb von $$-Blöcken. Die
-- beiden Kennungen werden deshalb als Sitzungsparameter abgelegt, dort liest
-- current_setting() sie sauber.
select set_config('demo.betrieb', :'betrieb', false),
       set_config('demo.inhaber', :'inhaber', false);

-- ------------------------------------------------------------ Mitarbeiter ----
insert into mitarbeiter (betrieb_id, name, kuerzel, stundensatz) values
  (:'betrieb', 'Katrin Vollmer',  'KV', 68.00),
  (:'betrieb', 'Marek Sobczak',   'MS', 62.00),
  (:'betrieb', 'Tobias Reinhardt','TR', 62.00),
  (:'betrieb', 'Yusuf Aydın',     'YA', 54.00)
on conflict do nothing;

-- Der Gründer hat noch keinen Satz; ohne ihn steht seine Arbeit später mit
-- null Euro in der Nachkalkulation.
update mitarbeiter set stundensatz = 75.00, kuerzel = 'FB'
 where betrieb_id = :'betrieb' and stundensatz = 0;

-- ------------------------------------------------------------- Lieferanten ---
-- lieferant führt bewusst keine Anschrift und keine Nummer: die Tabelle
-- beschreibt bisher nur die Anbindung an den Großhandel (IDS) und ob jemand
-- zusätzlich als Subunternehmer einplanbar ist. Für Bestellungen fehlen dort
-- Felder — vermerkt in docs/offene-fragen.md.
insert into lieferant (betrieb_id, name, ist_subunternehmer, ids_version)
select :'betrieb'::uuid, l.name, l.sub, l.ids
from (values
  ('Richter Haustechnik GmbH',     false, '2.5'),
  ('Nordwest Sanitär + Heizung eG', false, '2.3'),
  ('Fliesen Demirci GbR',           true,  null)
) as l(name, sub, ids)
where not exists (
  select 1 from lieferant v where v.betrieb_id = :'betrieb' and v.name = l.name
);

-- ----------------------------------------------------------------- Artikel ---
insert into artikel (betrieb_id, nummer, bezeichnung, einheit, ek_preis, vk_preis, lieferant_id)
select :'betrieb'::uuid, a.nummer, a.bezeichnung, a.einheit, a.ek, a.vk,
       (select id from lieferant where betrieb_id = :'betrieb' and name = a.lief)
from (values
  ('A-1001','Waschtisch Subway 3.0, 60 cm',            'Stk', 198.00,  289.00, 'Richter Haustechnik GmbH'),
  ('A-1002','WC-Element Duofix, 112 cm',               'Stk', 118.00,  165.00, 'Richter Haustechnik GmbH'),
  ('A-1003','Betätigungsplatte Sigma20, weiß/chrom',   'Stk', 132.00,  189.00, 'Richter Haustechnik GmbH'),
  ('A-1004','Duschrinne Edelstahl 900 mm',             'Stk', 171.00,  245.00, 'Richter Haustechnik GmbH'),
  ('A-1005','Einhebel-Waschtischarmatur, verchromt',   'Stk',  74.00,  119.00, 'Richter Haustechnik GmbH'),
  ('A-2001','Brennwerttherme 20 kW, wandhängend',      'Stk',1780.00, 2480.00, 'Nordwest Sanitär + Heizung eG'),
  ('A-2002','Heizkörper Kompakt 600 × 1000',           'Stk', 102.00,  148.00, 'Nordwest Sanitär + Heizung eG'),
  ('A-3001','Kupferrohr 18 × 1 mm',                    'm',     6.20,    9.80, 'Nordwest Sanitär + Heizung eG'),
  ('A-3002','Verbundrohr 16 × 2 mm',                   'm',     2.45,    3.90, 'Nordwest Sanitär + Heizung eG'),
  ('A-3003','Dämmschlauch 18 mm, 13 mm Stärke',        'm',     1.80,    3.20, 'Nordwest Sanitär + Heizung eG')
) as a(nummer, bezeichnung, einheit, ek, vk, lief)
on conflict (betrieb_id, nummer) do nothing;

-- ------------------------------------------------------------------ Kunden ---
insert into kunde (betrieb_id, nummer, name, strasse, plz, ort, ust_id,
                   reverse_charge_bau, zahlungsziel_tage, skonto_prozent, skonto_tage) values
  (:'betrieb','K-1001','Hausverwaltung Lindner GmbH','Kaiserstraße 118','44135','Dortmund','DE812345678', false, 30, 2.00, 10),
  -- § 13b UStG: ein Bauunternehmen, das selbst Bauleistungen erbringt.
  (:'betrieb','K-1002','Kessler Bau GmbH & Co. KG','Zeche-Holland-Straße 3','44653','Herne','DE287654321', true,  30, 0,    0),
  (:'betrieb','K-1003','Familie Ortmann','Lindenstraße 4','44287','Dortmund',null, false, 14, 0, 0),
  (:'betrieb','K-1004','Stadtwerke Mühlheim AöR','Aktienstraße 20','45473','Mülheim an der Ruhr','DE119876543', false, 30, 0, 0),
  (:'betrieb','K-1005','Immobilien Sanders KG','Hohe Straße 61','44139','Dortmund','DE145678912', false, 21, 3.00, 7),
  (:'betrieb','K-1006','Zahnarztpraxis Dr. Weinert','Marktplatz 9','58239','Schwerte',null, false, 14, 0, 0)
on conflict (betrieb_id, nummer) do nothing;

insert into ansprechpartner (betrieb_id, kunde_id, name, telefon, email)
select :'betrieb'::uuid, k.id, a.name, a.tel, a.mail
from (values
  ('K-1001','Petra Lindner',   '0231 55480-12', 'p.lindner@hv-lindner.example'),
  ('K-1001','Sven Adamczyk',   '0231 55480-17', 's.adamczyk@hv-lindner.example'),
  ('K-1002','Dipl.-Ing. Ralf Kessler','02323 9914-0','r.kessler@kessler-bau.example'),
  ('K-1004','Beschaffung Technik','0208 4501-330','technik@swm.example'),
  ('K-1005','Andrea Sanders',  '0231 7789-4',   'a.sanders@sanders-immo.example')
) as a(kundennr, name, tel, mail)
join kunde k on k.betrieb_id = :'betrieb' and k.nummer = a.kundennr
on conflict do nothing;

-- ---------------------------------------------------------------- Projekte ---
insert into projekt (betrieb_id, kunde_id, nummer, bezeichnung, strasse, plz, ort, status, beginn, ende)
select :'betrieb'::uuid, k.id, p.nummer, p.bez, p.strasse, p.plz, p.ort, p.status::projekt_status, p.beginn, p.ende
from (values
  ('K-1003','P-2601','Bad Erdgeschoss, Komplettsanierung','Lindenstraße 4','44287','Dortmund','laufend',      date '2026-08-10', date '2026-09-11'),
  ('K-1001','P-2602','Heizungstausch MFH, 12 Wohneinheiten','Ahornweg 12','44269','Dortmund','geplant',       date '2026-09-21', date '2026-11-13'),
  ('K-1002','P-2603','Sanitär Rohinstallation Wohnpark Süd, BA 1','Am Südhang 2-8','44227','Dortmund','laufend', date '2026-07-06', date '2026-10-30'),
  ('K-1005','P-2604','Rohrbruch Kirchgasse, Instandsetzung','Kirchgasse 7','44139','Dortmund','abgeschlossen', date '2026-06-15', date '2026-06-17'),
  ('K-1006','P-2605','Barrierefreies WC, Praxisumbau','Marktplatz 9','58239','Schwerte','geplant',            date '2026-10-05', null)
) as p(kundennr, nummer, bez, strasse, plz, ort, status, beginn, ende)
join kunde k on k.betrieb_id = :'betrieb' and k.nummer = p.kundennr
on conflict (betrieb_id, nummer) do nothing;

-- ------------------------------------------------------------------ Belege ---
-- Angelegt wird als Entwurf, festgeschrieben über beleg_festschreiben(). Der
-- Weg ist derselbe wie in der Anwendung: die Nummer kommt aus dem Nummernkreis,
-- die Prüfungen laufen, das Journal schreibt mit.

-- 1) Bad Erdgeschoss: Angebot -> Auftrag, beide festgeschrieben.
do $$
declare
  v_betrieb uuid := current_setting('demo.betrieb')::uuid;
  v_inhaber uuid := current_setting('demo.inhaber')::uuid;
  v_kunde   uuid;
  v_projekt uuid;
  v_angebot uuid;
  v_auftrag uuid;
begin
  select id into v_kunde   from kunde   where betrieb_id = v_betrieb and nummer = 'K-1003';
  select id into v_projekt from projekt where betrieb_id = v_betrieb and nummer = 'P-2601';

  insert into beleg (betrieb_id, kunde_id, projekt_id, art, datum, betreff, erstellt_von)
  values (v_betrieb, v_kunde, v_projekt, 'angebot', date '2026-07-28',
          'Komplettsanierung Bad Erdgeschoss', v_inhaber)
  returning id into v_angebot;

  insert into beleg_position
    (betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit, einzelpreis,
     steuersatz, lohn_anteil, material_anteil, lohn_minuten)
  values
    (v_betrieb, v_angebot, 1, 'titel',    'Demontage und Entsorgung', 0, '',   0,    19,  0,      0,   0),
    (v_betrieb, v_angebot, 2, 'leistung', 'Sanitärobjekte demontieren, Fliesen abschlagen', 14, 'm²', 42.00, 19, 31.00, 0,  38),
    (v_betrieb, v_angebot, 3, 'material', 'Container 7 m³ inkl. Entsorgung', 1, 'Stk', 380.00, 19, 0, 295.00, 0),
    (v_betrieb, v_angebot, 4, 'titel',    'Rohinstallation', 0, '', 0, 19, 0, 0, 0),
    (v_betrieb, v_angebot, 5, 'leistung', 'Wasser- und Abwasserleitungen neu verlegen', 1, 'psch', 1850.00, 19, 1290.00, 320.00, 1080),
    (v_betrieb, v_angebot, 6, 'material', 'Verbundrohr 16 × 2 mm', 65, 'm', 3.90, 19, 0, 2.45, 0),
    (v_betrieb, v_angebot, 7, 'titel',    'Objekte und Armaturen', 0, '', 0, 19, 0, 0, 0),
    (v_betrieb, v_angebot, 8, 'material', 'Waschtisch Subway 3.0, 60 cm', 1, 'Stk', 289.00, 19, 0, 198.00, 0),
    (v_betrieb, v_angebot, 9, 'material', 'WC-Element Duofix mit Betätigungsplatte', 1, 'Stk', 354.00, 19, 0, 250.00, 0),
    (v_betrieb, v_angebot,10, 'material', 'Duschrinne Edelstahl 900 mm', 1, 'Stk', 245.00, 19, 0, 171.00, 0),
    (v_betrieb, v_angebot,11, 'leistung', 'Montage Sanitärobjekte und Armaturen', 9, 'h', 68.00, 19, 52.00, 0, 60),
    (v_betrieb, v_angebot,12, 'text',     'Fliesenarbeiten werden gesondert durch die Firma Demirci ausgeführt.', 0, '', 0, 19, 0, 0, 0);

  perform beleg_festschreiben(v_angebot);

  -- Der Kunde hat angenommen; daraus wird der Auftrag.
  insert into beleg (betrieb_id, kunde_id, projekt_id, art, datum, betreff, vorgaenger_id, erstellt_von)
  values (v_betrieb, v_kunde, v_projekt, 'auftrag', date '2026-08-06',
          'Komplettsanierung Bad Erdgeschoss', v_angebot, v_inhaber)
  returning id into v_auftrag;

  insert into beleg_position
    (betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit, einzelpreis,
     steuersatz, lohn_anteil, material_anteil, lohn_minuten)
  select v_betrieb, v_auftrag, position_nr, art, bezeichnung, menge, einheit, einzelpreis,
         steuersatz, lohn_anteil, material_anteil, lohn_minuten
    from beleg_position where beleg_id = v_angebot;

  perform beleg_festschreiben(v_auftrag);
end $$;

-- 2) Heizungstausch: Angebot bleibt Entwurf, damit es etwas zu bearbeiten gibt.
do $$
declare
  v_betrieb uuid := current_setting('demo.betrieb')::uuid;
  v_inhaber uuid := current_setting('demo.inhaber')::uuid;
  v_kunde uuid; v_projekt uuid; v_beleg uuid;
begin
  select id into v_kunde   from kunde   where betrieb_id = v_betrieb and nummer = 'K-1001';
  select id into v_projekt from projekt where betrieb_id = v_betrieb and nummer = 'P-2602';

  insert into beleg (betrieb_id, kunde_id, projekt_id, art, datum, betreff, erstellt_von)
  values (v_betrieb, v_kunde, v_projekt, 'angebot', current_date,
          'Heizungstausch MFH Ahornweg 12', v_inhaber)
  returning id into v_beleg;

  insert into beleg_position
    (betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit, einzelpreis,
     steuersatz, lohn_anteil, material_anteil, lohn_minuten)
  values
    (v_betrieb, v_beleg, 1, 'titel',    'Wärmeerzeuger', 0, '', 0, 19, 0, 0, 0),
    (v_betrieb, v_beleg, 2, 'material', 'Brennwerttherme 20 kW, wandhängend', 1, 'Stk', 2480.00, 19, 0, 1780.00, 0),
    (v_betrieb, v_beleg, 3, 'leistung', 'Altgerät demontieren und entsorgen', 1, 'psch', 420.00, 19, 310.00, 40.00, 240),
    (v_betrieb, v_beleg, 4, 'leistung', 'Montage, Anbindung, Inbetriebnahme', 16, 'h', 68.00, 19, 52.00, 0, 60),
    (v_betrieb, v_beleg, 5, 'titel',    'Heizkörper', 0, '', 0, 19, 0, 0, 0),
    (v_betrieb, v_beleg, 6, 'material', 'Heizkörper Kompakt 600 × 1000', 12, 'Stk', 148.00, 19, 0, 102.00, 0),
    (v_betrieb, v_beleg, 7, 'leistung', 'Heizkörper tauschen, hydraulischer Abgleich', 12, 'Stk', 96.00, 19, 71.00, 0, 75);
end $$;

-- 3) Wohnpark Süd: Abschlagsrechnung an ein Bauunternehmen — § 13b UStG, also
--    ohne Umsatzsteuer. Der Steuersatz steht auf 0, das Kennzeichen am Kunden.
do $$
declare
  v_betrieb uuid := current_setting('demo.betrieb')::uuid;
  v_inhaber uuid := current_setting('demo.inhaber')::uuid;
  v_kunde uuid; v_projekt uuid; v_beleg uuid;
begin
  select id into v_kunde   from kunde   where betrieb_id = v_betrieb and nummer = 'K-1002';
  select id into v_projekt from projekt where betrieb_id = v_betrieb and nummer = 'P-2603';

  insert into beleg (betrieb_id, kunde_id, projekt_id, art, datum, leistungsdatum,
                     betreff, erstellt_von)
  values (v_betrieb, v_kunde, v_projekt, 'abschlagsrechnung', date '2026-08-04', date '2026-07-31',
          '1. Abschlag Rohinstallation BA 1', v_inhaber)
  returning id into v_beleg;

  insert into beleg_position
    (betrieb_id, beleg_id, position_nr, art, bezeichnung, menge, einheit, einzelpreis,
     steuersatz, lohn_anteil, material_anteil, lohn_minuten)
  values
    (v_betrieb, v_beleg, 1, 'text',     'Leistungsstand zum 31.07.2026, Aufstellung anbei (§ 632a BGB).', 0, '', 0, 0, 0, 0, 0),
    (v_betrieb, v_beleg, 2, 'leistung', 'Rohinstallation Kaltwasser, Stränge 1–4', 1, 'psch', 8400.00, 0, 5900.00, 1200.00, 0),
    (v_betrieb, v_beleg, 3, 'leistung', 'Abwassergrundleitungen, Bauabschnitt 1', 1, 'psch', 5200.00, 0, 3600.00,  800.00, 0),
    (v_betrieb, v_beleg, 4, 'text',     'Steuerschuldnerschaft des Leistungsempfängers (§ 13b Abs. 2 Nr. 4 UStG).', 0, '', 0, 0, 0, 0, 0);

  perform beleg_festschreiben(v_beleg);

  -- Eingang auf dem Bankkonto. Bei § 13b traegt der Leistungsempfaenger die
  -- Steuer, deshalb Steuerbetrag null und der Status an der Vereinnahmung.
  insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                       steuersatz, steuerbetrag, status_rc, art, bemerkung)
  values (v_betrieb, v_beleg, date '2026-08-19', 13600.00, 13600.00, 0, 0,
          'rc_13b_nr4', 'abschlag', 'Überweisung, vollständig');
end $$;

-- ------------------------------------------------------------- Zeiterfassung --
-- Zeiten auf die laufenden Baustellen. position_id bleibt leer: erfasst, aber
-- noch nicht abgerechnet.
do $$
declare
  v_betrieb uuid := current_setting('demo.betrieb')::uuid;
  v_bad     uuid;
  v_sued    uuid;
  v_tag     date;
  v_person  uuid;
  i         integer := 0;
begin
  select id into v_bad  from projekt where betrieb_id = v_betrieb and nummer = 'P-2601';
  select id into v_sued from projekt where betrieb_id = v_betrieb and nummer = 'P-2603';

  for v_tag in
    select d::date from generate_series(current_date - 11, current_date - 1, interval '1 day') d
     where extract(isodow from d) < 6      -- Montag bis Freitag
  loop
    for v_person in
      select id from mitarbeiter where betrieb_id = v_betrieb and aktiv order by name limit 3
    loop
      i := i + 1;
      insert into zeiteintrag (id, betrieb_id, projekt_id, mitarbeiter_id, beginn, ende,
                               pause_minuten, taetigkeit)
      values (
        gen_random_uuid(), v_betrieb,
        case when i % 3 = 0 then v_sued else v_bad end,
        v_person,
        v_tag + time '07:00' + (i % 2) * interval '30 minutes',
        v_tag + time '16:00' + (i % 3) * interval '15 minutes',
        30,
        case i % 4
          when 0 then 'Rohinstallation'
          when 1 then 'Montage Sanitärobjekte'
          when 2 then 'Demontage und Entsorgung'
          else 'Baustelleneinrichtung'
        end
      );
    end loop;
  end loop;
end $$;
