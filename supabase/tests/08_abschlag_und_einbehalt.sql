-- Abschlagszahlungen, Absetzung, Einbehalte, Skonto und Reverse Charge.
-- Prueft vor allem die vier harten Negativregeln aus docs/rechnungsmodell.md:
-- was das System NICHT tun darf.
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
insert into kunde (id, betrieb_id, name, zahlungsziel_tage) values
  ('a1000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a', 'Stadt Musterhausen', 30);
insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('a2000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-00000000000a',
   'a1000000-0000-0000-0000-00000000000a', 'Kita Ahornweg');

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- Abschlagsrechnung ueber 10.000 netto, festgeschrieben und vereinnahmt.
do $$
declare v uuid; nr text;
begin
  insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-00000000000a',
          'abschlagsrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Abschlag 1', 1, 10000);
  nr := beleg_festschreiben(v);
  perform set_config('test.abschlag', v::text, false);
  perform set_config('test.abschlag_nr', nr, false);

  -- UStAE 13.6 Abs. 1 Satz 3: das Gutschriftsdatum, nicht das Rechnungsdatum.
  insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto,
                       entgelt_netto, steuersatz, steuerbetrag, art)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, current_date - 5,
          11900.00, 10000.00, 19, 1900.00, 'abschlag');
end $$;

-- ------------------------------------------------ 1. Die § 14c-Falle -------
-- Eine Schlussrechnung, die die vereinnahmte Abschlagszahlung nicht absetzt,
-- darf nicht festgeschrieben werden koennen.
do $$
declare v uuid;
begin
  insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-00000000000a',
          'schlussrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Gesamtleistung', 1, 25000);
  perform set_config('test.schluss', v::text, false);

  begin
    perform beleg_festschreiben(v);
    raise exception 'FAIL Schlussrechnung ohne Absetzung der Abschlagszahlung wurde festgeschrieben';
  exception when restrict_violation then null;
  end;
end $$;

-- ------------------------------- 2. Mit Absetzung geht sie durch -----------
do $$
declare
  v_schluss uuid := current_setting('test.schluss')::uuid;
  v_ab      uuid := current_setting('test.abschlag')::uuid;
  z         zahlung%rowtype;
begin
  select * into z from zahlung where beleg_id = v_ab;
  insert into beleg_anrechnung (betrieb_id, schlussrechnung_id, abschlagsrechnung_id, zahlung_id,
                                vereinnahmt_am, entgelt_netto, steuersatz, steuerbetrag,
                                angerechnet_brutto, status_rc, vorbeleg_nummer, vorbeleg_datum)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v_schluss, v_ab, z.id,
          z.vereinnahmt_am, z.entgelt_netto, z.steuersatz, z.steuerbetrag,
          z.betrag_brutto, z.status_rc, current_setting('test.abschlag_nr'), current_date);
  perform beleg_festschreiben(v_schluss);
exception when restrict_violation then
  raise exception 'FAIL Schlussrechnung mit vollstaendiger Absetzung wurde blockiert: %', sqlerrm;
end $$;

-- ---------------- 3. Ein Storno entfernt den Abschlag nicht aus der Basis ---
-- UStAE 14.8 Abs. 9 Satz 1: die Absetzungspflicht bleibt bestehen, auch wenn
-- die Abschlagsrechnung nachtraeglich zurueckgenommen wird.
do $$
declare v uuid; n integer;
begin
  insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-00000000000a',
          'schlussrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Zweite Schlussrechnung', 1, 25000);

  -- Die Abschlagsrechnung auf storniert setzen aendert nichts an der Pflicht.
  update beleg set storniert_durch = id, status = 'storniert'
   where id = current_setting('test.abschlag')::uuid;

  begin
    perform beleg_festschreiben(v);
    raise exception 'FAIL stornierte Abschlagsrechnung fiel aus der Absetzungsbasis';
  exception when restrict_violation then null;
  end;
  delete from beleg_position where beleg_id = v;
  delete from beleg where id = v;
end $$;

-- ------------------------ 4. Der Einbehalt fasst den Beleg nie an ----------
do $$
declare
  v_schluss uuid := current_setting('test.schluss')::uuid;
  v_sich uuid; n numeric; b numeric; zb numeric;
begin
  select netto, brutto into n, b from beleg where id = v_schluss;

  insert into sicherheit (betrieb_id, projekt_id, zweck, art, rate_prozent,
                          sicherheitssumme_soll, basis_bemessung, basis_einbehalt)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-00000000000a',
          'maengelansprueche', 'einbehalt', 5.00, 1500.00, 'abrechnungssumme', 'brutto')
  returning id into v_sich;
  insert into einbehalt_position (betrieb_id, beleg_id, sicherheit_id, betrag, faellig_ab)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v_schluss, v_sich, 1487.50, current_date + 1825);

  -- § 10 Abs. 1 Satz 2 UStG: Bemessungsgrundlage und Steuer bleiben unberuehrt.
  if (select netto from beleg where id = v_schluss) <> n
     or (select brutto from beleg where id = v_schluss) <> b then
    raise exception 'FAIL Einbehalt hat die Belegsummen veraendert';
  end if;

  -- Nur der jetzt faellige Zahlbetrag sinkt.
  select zahlbetrag into zb from v_beleg_zahlungsstand where beleg_id = v_schluss;
  if zb <> b - 1487.50 then
    raise exception 'FAIL Zahlbetrag % statt %', zb, b - 1487.50;
  end if;
end $$;

-- ------------------------------ 5. Skonto erzeugt keinen Beleg -------------
do $$
declare v_schluss uuid := current_setting('test.schluss')::uuid; vorher integer; nachher integer;
begin
  select count(*) into vorher from beleg where nummer is not null;
  insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                       steuersatz, steuerbetrag, art, skonto_brutto,
                       entgeltminderung_netto, ust_korrekturbetrag)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v_schluss, current_date,
          16000.00, 13445.38, 19, 2554.62, 'schlusszahlung', 476.00, 400.00, 76.00);
  select count(*) into nachher from beleg where nummer is not null;
  if nachher <> vorher then
    raise exception 'FAIL Skonto hat % Beleg(e) erzeugt', nachher - vorher;
  end if;
end $$;

-- --------------------- 6. Unterzahlung erzeugt keinen Korrekturbeleg -------
-- UStAE 14.8 Abs. 5 Saetze 4-5: die Steuer entsteht nur auf den vereinnahmten
-- Betrag, eine Rechnungsberichtigung ist nicht erforderlich.
do $$
declare v uuid; vorher integer; nachher integer;
begin
  insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', null,
          'abschlagsrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, 1, 'Abschlag', 1, 5000);
  perform beleg_festschreiben(v);

  select count(*) into vorher from beleg where nummer is not null;
  insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                       steuersatz, steuerbetrag, art)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, current_date, 2380.00, 2000.00, 19, 380.00, 'abschlag');
  select count(*) into nachher from beleg where nummer is not null;
  if nachher <> vorher then
    raise exception 'FAIL Unterzahlung hat einen Korrekturbeleg erzeugt';
  end if;
end $$;

-- --------------------------------------- 7. Reverse Charge ohne Steuer -----
do $$
declare v uuid;
begin
  select current_setting('test.schluss')::uuid into v;
  begin
    insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                         steuersatz, steuerbetrag, art, status_rc)
    values ('aaaaaaaa-0000-0000-0000-00000000000a', v, current_date, 1190.00, 1000.00, 19, 190.00,
            'teilzahlung', 'rc_13b_nr4');
    raise exception 'FAIL Reverse-Charge-Zahlung mit ausgewiesener Steuer wurde angenommen';
  exception when check_violation then null;
  end;
end $$;

-- ---------------- 8. Reverse Charge vertraegt keinen Brutto-Einbehalt ------
-- § 17 Abs. 6 Nr. 1 Satz 2 VOB/B: es ist keine Umsatzsteuer ausgewiesen.
do $$
declare v uuid; s uuid;
begin
  insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-00000000000a',
          'a1000000-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-00000000000a',
          'teilrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v;
  insert into zahlung (betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto, entgelt_netto,
                       steuersatz, steuerbetrag, art, status_rc)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', v, current_date, 5000.00, 5000.00, 0, 0,
          'teilzahlung', 'rc_13b_nr4');
  select id into s from sicherheit where projekt_id = 'a2000000-0000-0000-0000-00000000000a';
  begin
    insert into einbehalt_position (betrieb_id, beleg_id, sicherheit_id, betrag)
    values ('aaaaaaaa-0000-0000-0000-00000000000a', v, s, 250.00);
    raise exception 'FAIL Brutto-Einbehalt auf einem Reverse-Charge-Beleg wurde angenommen';
  exception when restrict_violation then null;
  end;
end $$;

-- ------------------------------------------- 9. Grenzen der Sicherheit -----
do $$
declare s uuid;
begin
  select id into s from sicherheit where projekt_id = 'a2000000-0000-0000-0000-00000000000a';
  begin
    update sicherheit set einbehalten_ist = 2000.00 where id = s;   -- Soll ist 1500
    raise exception 'FAIL Einbehalt ueber der Sicherheitssumme wurde angenommen';
  exception when check_violation then null;
  end;
  -- § 17 Abs. 8 Nr. 1 VOB/B: nie zwei aktive Sicherheiten desselben Zwecks.
  begin
    insert into sicherheit (betrieb_id, projekt_id, zweck, art, sicherheitssumme_soll,
                            basis_bemessung, basis_einbehalt)
    values ('aaaaaaaa-0000-0000-0000-00000000000a', 'a2000000-0000-0000-0000-00000000000a',
            'maengelansprueche', 'buergschaft', 1000, 'auftragssumme', 'netto');
    raise exception 'FAIL zweite aktive Sicherheit desselben Zwecks wurde angenommen';
  exception when unique_violation then null;
  end;
end $$;

reset role;
\echo '  OK  Abschlag, Absetzung, Einbehalt, Skonto, Reverse Charge'
