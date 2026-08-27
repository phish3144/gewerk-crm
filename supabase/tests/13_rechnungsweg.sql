-- Der Rechnungsweg: Auftrag, Abschlag, Zahlung, Absetzung, Schlussrechnung.
--
-- Der teuerste Fehler im Handwerk ist hier zu Hause: wer die vereinnahmten
-- Abschlaege in der Schlussrechnung nicht absetzt, schuldet die Umsatzsteuer
-- darauf ein zweites Mal (§ 14c Abs. 1 UStG). Geprueft wird deshalb beides -
-- dass es ohne Absetzung nicht geht, und dass die Absetzung stimmt.

\set ON_ERROR_STOP on

insert into benutzer (id, email, anzeigename) values
  ('33330000-1111-0000-0000-000000000001', 'buero@rechnung.de', 'Buero');
insert into betrieb (id, name, ust_id) values
  ('33330000-0000-0000-0000-00000000000a', 'Rechnungsbetrieb', 'DE123456789');
insert into benutzer_betrieb values
  ('33330000-1111-0000-0000-000000000001', '33330000-0000-0000-0000-00000000000a', 'inhaber');
insert into kunde (id, betrieb_id, name, strasse, plz, ort, zahlungsziel_tage) values
  ('33330000-2000-0000-0000-00000000000a', '33330000-0000-0000-0000-00000000000a',
   'Bauherr GmbH', 'Musterweg 1', '10115', 'Berlin', 14);
insert into projekt (id, betrieb_id, kunde_id, bezeichnung) values
  ('33330000-3000-0000-0000-00000000000a', '33330000-0000-0000-0000-00000000000a',
   '33330000-2000-0000-0000-00000000000a', 'Sanierung Musterweg');

set role authenticated;
set request.jwt.claim.sub = '33330000-1111-0000-0000-000000000001';

-- ------------------------------------------------------ Abschlagsrechnung ---
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von) values
  ('33330000-5000-0000-0000-000000000001', '33330000-0000-0000-0000-00000000000a',
   '33330000-2000-0000-0000-00000000000a', '33330000-3000-0000-0000-00000000000a',
   'abschlagsrechnung', current_date, '33330000-1111-0000-0000-000000000001');
insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einheit, einzelpreis, steuersatz) values
  ('33330000-0000-0000-0000-00000000000a', '33330000-5000-0000-0000-000000000001',
   1, '1. Abschlag Rohbau', 1, 'Psch', 10000.00, 19);
select beleg_festschreiben('33330000-5000-0000-0000-000000000001');

-- Vereinnahmt: 11.900,00 brutto = 10.000,00 netto + 1.900,00 Steuer.
insert into zahlung (id, betrieb_id, beleg_id, vereinnahmt_am, betrag_brutto,
                     entgelt_netto, steuersatz, steuerbetrag, art)
values ('33330000-7000-0000-0000-000000000001', '33330000-0000-0000-0000-00000000000a',
        '33330000-5000-0000-0000-000000000001', current_date - 30, 11900.00,
        10000.00, 19, 1900.00, 'abschlag');

-- ------------------------------------------------------- Schlussrechnung ----
insert into beleg (id, betrieb_id, kunde_id, projekt_id, art, leistungsdatum, erstellt_von) values
  ('33330000-5000-0000-0000-000000000002', '33330000-0000-0000-0000-00000000000a',
   '33330000-2000-0000-0000-00000000000a', '33330000-3000-0000-0000-00000000000a',
   'schlussrechnung', current_date, '33330000-1111-0000-0000-000000000001');
insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einheit, einzelpreis, steuersatz) values
  ('33330000-0000-0000-0000-00000000000a', '33330000-5000-0000-0000-000000000002',
   1, 'Gesamtleistung Sanierung', 1, 'Psch', 25000.00, 19);

-- Ohne Absetzung laesst die Datenbank nicht festschreiben. Das ist der
-- eigentliche Wert dieser Pruefung: der Fehler kostet echtes Geld.
do $$
begin
  begin
    perform beleg_festschreiben('33330000-5000-0000-0000-000000000002');
    raise exception 'FAIL die Schlussrechnung liess sich ohne Absetzung festschreiben';
  exception when restrict_violation then null;
  end;
end $$;

-- ------------------------------------------------------------- Absetzung ----
do $$
declare n integer;
begin
  n := abschlaege_anrechnen('33330000-5000-0000-0000-000000000002');
  if n <> 1 then
    raise exception 'FAIL % Absetzungszeilen statt 1', n;
  end if;

  -- Kopiert, nicht neu gerechnet: Satz, Betrag und Vorbelegnummer von damals.
  if not exists (
    select 1 from beleg_anrechnung
     where schlussrechnung_id = '33330000-5000-0000-0000-000000000002'
       and entgelt_netto = 10000.00 and steuerbetrag = 1900.00
       and angerechnet_brutto = 11900.00 and steuersatz = 19
       and vorbeleg_nummer like 'AR-%'
  ) then
    raise exception 'FAIL die Absetzungszeile traegt nicht die Werte der Zahlung';
  end if;

  -- Ein zweiter Aufruf darf nichts verdoppeln.
  n := abschlaege_anrechnen('33330000-5000-0000-0000-000000000002');
  if n <> 0 then
    raise exception 'FAIL der zweite Aufruf hat % weitere Zeilen erzeugt', n;
  end if;
end $$;

do $$
declare v_nummer text; v_beleg record;
begin
  v_nummer := beleg_festschreiben('33330000-5000-0000-0000-000000000002');
  if v_nummer not like 'RE-%' then
    raise exception 'FAIL die Schlussrechnungsnummer lautet %', v_nummer;
  end if;

  select * into v_beleg from beleg where id = '33330000-5000-0000-0000-000000000002';
  if v_beleg.netto <> 25000.00 or v_beleg.steuer <> 4750.00 or v_beleg.brutto <> 29750.00 then
    raise exception 'FAIL Summen: netto %, steuer %, brutto %',
      v_beleg.netto, v_beleg.steuer, v_beleg.brutto;
  end if;

  -- § 14 Abs. 4 Nr. 1 UStG: der Name des Leistungsempfaengers ist eingefroren.
  if v_beleg.kunde_name <> 'Bauherr GmbH' then
    raise exception 'FAIL die Kundenkopie fehlt oder stimmt nicht: %', v_beleg.kunde_name;
  end if;
  -- Faelligkeit aus dem Zahlungsziel des Kunden, ebenfalls eingefroren.
  if v_beleg.faelligkeit_am <> v_beleg.datum + 14 then
    raise exception 'FAIL Faelligkeit % statt %', v_beleg.faelligkeit_am, v_beleg.datum + 14;
  end if;
end $$;

-- Zahlbetrag: 29.750,00 brutto minus 11.900,00 angerechnet = 17.850,00.
do $$
declare v_offen numeric;
begin
  select b.brutto - coalesce(sum(a.angerechnet_brutto), 0) into v_offen
    from beleg b
    left join beleg_anrechnung a on a.schlussrechnung_id = b.id
   where b.id = '33330000-5000-0000-0000-000000000002'
   group by b.brutto;
  if v_offen <> 17850.00 then
    raise exception 'FAIL Zahlbetrag % statt 17.850,00', v_offen;
  end if;
end $$;

-- ---------------------------------------------- Absetzung ist unumkehrbar ---
-- Die festgeschriebene Schlussrechnung darf ihre Absetzungsbasis nicht
-- verlieren. Zwei Schranken stehen davor, und die aeussere greift zuerst: die
-- GoBD-Sperre auf festgeschriebenen Belegen (0010). Erst wenn die faellt,
-- kaeme der Fremdschluessel der Absetzung zum Zug. Geprueft wird, dass die
-- Zeile am Ende noch da ist - welcher der beiden Riegel haelt, ist zweitrangig.
do $$
declare v_zustand text; n integer;
begin
  begin
    delete from beleg where id = '33330000-5000-0000-0000-000000000001';
    raise exception 'FAIL die abgesetzte Abschlagsrechnung liess sich loeschen';
  exception when others then
    get stacked diagnostics v_zustand = returned_sqlstate;
    -- 23503 Fremdschluessel, 23001 restrict_violation aus dem GoBD-Trigger.
    if v_zustand not in ('23503', '23001') then
      raise;
    end if;
  end;

  select count(*) into n from beleg where id = '33330000-5000-0000-0000-000000000001';
  if n <> 1 then
    raise exception 'FAIL die Abschlagsrechnung ist nach dem Loeschversuch weg';
  end if;
end $$;

-- ----------------------------------------------------------- Aufraeumen -----
select betrieb_loeschen('33330000-0000-0000-0000-00000000000a');
reset role;
delete from benutzer where id = '33330000-1111-0000-0000-000000000001';

\echo '  OK  Rechnungsweg: Abschlag, Zahlung, Absetzung nach § 14 Abs. 5 UStG, Schlussrechnung, Zahlbetrag'
