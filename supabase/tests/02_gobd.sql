-- GoBD und Belegkette. Prueft, dass festgeschriebene Belege wirklich
-- unveraenderlich sind und Nummernkreise keine Luecken bekommen.
\set ON_ERROR_STOP on
\set QUIET on

reset role;
truncate betrieb, benutzer cascade;
-- Das Journal wird NICHT geleert: es ist anfuegend (0011). Aussagen darueber
-- grenzen sich stattdessen auf den Mandanten dieses Tests ein.

insert into benutzer (id, email, anzeigename) values
  ('11111111-1111-1111-1111-111111111111', 'anna@bergmann-elektro.de', 'Anna Bergmann');
insert into betrieb (id, name) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Elektro Bergmann GmbH');
insert into benutzer_betrieb (benutzer_id, betrieb_id, rolle) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'inhaber');
insert into kunde (id, betrieb_id, name) values
  ('a1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Stadt Musterhausen');

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ------------------------------------------------- Summen aus den Positionen --
do $$
declare v_beleg uuid; b beleg%rowtype;
begin
  insert into beleg (betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
          'schlussrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v_beleg;

  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einheit,
                              einzelpreis, steuersatz, lohn_anteil, material_anteil)
  values ('aaaaaaaa-0000-0000-0000-000000000001', v_beleg, 1, 'Leerrohr M25 unter Putz',
          420, 'm', 7.80, 19, 5.20, 2.60),
         ('aaaaaaaa-0000-0000-0000-000000000001', v_beleg, 2, 'Schalterdose UP setzen',
          96, 'St', 12.40, 19, 9.60, 2.80);

  select * into b from beleg where id = v_beleg;
  -- 420 x 7,80 = 3.276,00 ; 96 x 12,40 = 1.190,40 ; Summe 4.466,40
  if b.netto <> 4466.40 then raise exception 'FAIL Netto: % statt 4466.40', b.netto; end if;
  -- 19 % auf 4.466,40 = 848,616 -> kaufmaennisch 848,62
  if b.steuer <> 848.62 then raise exception 'FAIL Steuer: % statt 848.62', b.steuer; end if;
  if b.brutto <> 5315.02 then raise exception 'FAIL Brutto: % statt 5315.02', b.brutto; end if;

  perform set_config('test.beleg', v_beleg::text, false);
end $$;

-- ------------------------------------------------ Rechnung ohne Leistungsdatum --
do $$
declare v_beleg uuid;
begin
  insert into beleg (betrieb_id, kunde_id, art, erstellt_von)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
          'schlussrechnung', '11111111-1111-1111-1111-111111111111')
  returning id into v_beleg;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-000000000001', v_beleg, 1, 'Irgendwas', 1, 10);

  begin
    perform beleg_festschreiben(v_beleg);
    raise exception 'FAIL Pflichtangabe: Rechnung ohne Leistungsdatum wurde festgeschrieben';
  -- Seit 0009 tragen die Abbrueche einen eigenen Fehlercode (restrict_violation),
  -- damit die Anwendung Pflichtverletzungen von echten Fehlern unterscheiden kann.
  exception when raise_exception or restrict_violation then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  delete from beleg_position where beleg_id = v_beleg;
  delete from beleg where id = v_beleg;
end $$;

-- ------------------------------------------------------ Festschreiben wirkt --
do $$
declare v_beleg uuid := current_setting('test.beleg')::uuid; v_nr text; b beleg%rowtype;
begin
  v_nr := beleg_festschreiben(v_beleg);
  select * into b from beleg where id = v_beleg;
  if b.status <> 'festgeschrieben' then raise exception 'FAIL Status: %', b.status; end if;
  if b.nummer is null then raise exception 'FAIL Nummer fehlt'; end if;
  if b.festgeschrieben_am is null then raise exception 'FAIL Zeitstempel fehlt'; end if;
  if v_nr not like '%-00001' then raise exception 'FAIL Erste Nummer lautet %', v_nr; end if;
end $$;

-- ------------------------------------- Zweimal festschreiben geht nicht ------
do $$
declare v_beleg uuid := current_setting('test.beleg')::uuid;
begin
  begin
    perform beleg_festschreiben(v_beleg);
    raise exception 'FAIL Doppelt: Beleg liess sich zweimal festschreiben';
  -- Seit 0009 tragen die Abbrueche einen eigenen Fehlercode (restrict_violation),
  -- damit die Anwendung Pflichtverletzungen von echten Fehlern unterscheiden kann.
  exception when raise_exception or restrict_violation then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
end $$;

-- ------------------------------------------ Inhalt ist jetzt unveraenderlich --
do $$
declare v_beleg uuid := current_setting('test.beleg')::uuid;
begin
  begin
    update beleg set netto = 1 where id = v_beleg;
    raise exception 'FAIL Unveraenderbarkeit: Betrag liess sich aendern';
  exception when restrict_violation then null;
  end;

  begin
    update beleg set nummer = 'GEFAELSCHT' where id = v_beleg;
    raise exception 'FAIL Unveraenderbarkeit: Nummer liess sich aendern';
  exception when restrict_violation then null;
  end;

  begin
    delete from beleg where id = v_beleg;
    raise exception 'FAIL Loeschschutz: festgeschriebener Beleg liess sich loeschen';
  exception when restrict_violation then null;
  end;

  begin
    update beleg_position set einzelpreis = 1 where beleg_id = v_beleg;
    raise exception 'FAIL Positionsschutz: Position liess sich aendern';
  exception when restrict_violation then null;
  end;

  begin
    insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
    values ('aaaaaaaa-0000-0000-0000-000000000001', v_beleg, 99, 'Nachgeschoben', 1, 999);
    raise exception 'FAIL Positionsschutz: Position liess sich nachschieben';
  exception when restrict_violation then null;
  end;

  begin
    delete from beleg_position where beleg_id = v_beleg;
    raise exception 'FAIL Positionsschutz: Position liess sich loeschen';
  exception when restrict_violation then null;
  end;
end $$;

-- --------------------------------- Statuswechsel bleibt erlaubt --------------
do $$
declare v_beleg uuid := current_setting('test.beleg')::uuid;
begin
  update beleg set status = 'versendet' where id = v_beleg;
  update beleg set status = 'bezahlt'   where id = v_beleg;
end $$;

-- ------------------------------------------------ Nummernkreis ohne Luecken --
do $$
declare v_beleg uuid; v_nr text; v_nummern text[] := '{}';
begin
  for i in 1..3 loop
    insert into beleg (betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
            'schlussrechnung', current_date, '11111111-1111-1111-1111-111111111111')
    returning id into v_beleg;
    insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
    values ('aaaaaaaa-0000-0000-0000-000000000001', v_beleg, 1, 'Position', 1, 100);
    v_nr := beleg_festschreiben(v_beleg);
    v_nummern := v_nummern || v_nr;
  end loop;

  if right(v_nummern[1], 5) <> '00002' then raise exception 'FAIL Luecke: % nach 00001', v_nummern[1]; end if;
  if right(v_nummern[2], 5) <> '00003' then raise exception 'FAIL Luecke: %', v_nummern[2]; end if;
  if right(v_nummern[3], 5) <> '00004' then raise exception 'FAIL Luecke: %', v_nummern[3]; end if;
end $$;

-- ---------------------------- Verworfener Entwurf hinterlaesst keine Luecke --
do $$
declare v_beleg uuid; v_nr text;
begin
  insert into beleg (betrieb_id, kunde_id, art, erstellt_von)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
          'schlussrechnung', '11111111-1111-1111-1111-111111111111')
  returning id into v_beleg;
  delete from beleg where id = v_beleg;   -- Entwurf, also loeschbar

  insert into beleg (betrieb_id, kunde_id, art, leistungsdatum, erstellt_von)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
          'schlussrechnung', current_date, '11111111-1111-1111-1111-111111111111')
  returning id into v_beleg;
  insert into beleg_position (betrieb_id, beleg_id, position_nr, bezeichnung, menge, einzelpreis)
  values ('aaaaaaaa-0000-0000-0000-000000000001', v_beleg, 1, 'Position', 1, 100);
  v_nr := beleg_festschreiben(v_beleg);
  if right(v_nr, 5) <> '00005' then raise exception 'FAIL Entwurf hat eine Luecke gerissen: %', v_nr; end if;
end $$;

-- -------------------------------- Nummernkreis laesst sich nicht zurueckdrehen --
do $$
begin
  begin
    update nummernkreis set naechste = 1
     where betrieb_id = 'aaaaaaaa-0000-0000-0000-000000000001';
    raise exception 'FAIL Nummernkreis liess sich zuruecksetzen';
  -- Zwei Schichten duerfen abwehren: seit 0009 fehlt der Anwendungsrolle das
  -- Schreibrecht (insufficient_privilege), davor griff der Rueckwaerts-Trigger.
  exception when restrict_violation or insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------------- Journal fuehrt mit -------
do $$
declare n integer;
begin
  select count(*) into n from journal
   where tabelle = 'beleg' and aktion = 'insert'
     and betrieb_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if n < 5 then raise exception 'FAIL Journal: nur % Beleg-Eintraege', n; end if;

  select count(*) into n from journal where benutzer_id = '11111111-1111-1111-1111-111111111111';
  if n = 0 then raise exception 'FAIL Journal: kein Eintrag traegt den Benutzer'; end if;

  begin
    update journal set aktion = 'insert' where id = (select min(id) from journal);
    raise exception 'FAIL Journal liess sich aendern';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from journal where id = (select min(id) from journal);
    raise exception 'FAIL Journal liess sich loeschen';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
\echo '  OK  GoBD: Summen, Festschreibung, Unveraenderbarkeit, Nummernkreis, Journal'
