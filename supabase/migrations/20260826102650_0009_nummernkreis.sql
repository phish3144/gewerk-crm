-- Vier bestaetigte Befunde zum Nummernkreis, alle kritisch oder hoch:
--
--   * naechste_nummer war fuer 'authenticated' direkt aufrufbar - jeder Aufruf
--     verbrennt eine Nummer ohne Beleg und reisst eine Luecke.
--   * nummernkreis war fuer 'authenticated' voll schreibbar. DELETE + INSERT
--     umgeht den Rueckwaerts-Trigger vollstaendig und setzt den Zaehler zurueck.
--   * Nummern waren nur je Belegart eindeutig: Angebot, Abschlag, Teil- und
--     Schlussrechnung trugen alle "2026-00001".
--   * Die erste Nummer eines Jahres lief bei Gleichzeitigkeit in duplicate key.
--
-- Konsequenz: der Nummernkreis gehoert nicht in die Hand der Anwendungsrolle.
-- Er wird ausschliesslich ueber beleg_festschreiben fortgeschrieben, und diese
-- Funktion laeuft als security definer mit eigener Zugehoerigkeitspruefung.

-- Belegart im Praefix, damit Nummern betriebsweit eindeutig sind.
create or replace function nummer_praefix(p_art beleg_art)
  returns text
  language sql
  immutable
  as $$
    select case p_art
      when 'angebot'           then 'AN-'
      when 'auftrag'           then 'AU-'
      when 'abschlagsrechnung' then 'AR-'
      when 'teilrechnung'      then 'TR-'
      when 'schlussrechnung'   then 'RE-'
      when 'gutschrift'        then 'GU-'
      when 'storno'            then 'ST-'
    end
  $$;

-- Eindeutigkeit betriebsweit statt je Belegart.
alter table beleg drop constraint beleg_betrieb_id_art_nummer_key;
alter table beleg add  constraint beleg_nummer_eindeutig unique (betrieb_id, nummer);

-- Fortschreibung ohne Wettlauf: das INSERT legt den Kreis an, falls er fehlt,
-- das UPDATE erhoeht unter Zeilensperre und gibt den verbrauchten Wert zurueck.
-- Zwei gleichzeitige Festschreibungen serialisieren sich damit sauber, statt in
-- einen Schluesselkonflikt zu laufen.
create or replace function naechste_nummer(p_betrieb uuid, p_art beleg_art, p_jahr smallint)
  returns text
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_nr      integer;
  v_praefix text;
begin
  insert into nummernkreis (betrieb_id, art, jahr, praefix, naechste)
  values (p_betrieb, p_art, p_jahr, nummer_praefix(p_art), 1)
  on conflict (betrieb_id, art, jahr) do nothing;

  update nummernkreis
     set naechste = naechste + 1
   where betrieb_id = p_betrieb and art = p_art and jahr = p_jahr
  returning naechste - 1, praefix into v_nr, v_praefix;

  return format('%s%s-%s', v_praefix, p_jahr, lpad(v_nr::text, 5, '0'));
end $$;

drop function if exists naechste_nummer(uuid, beleg_art);
revoke all on function naechste_nummer(uuid, beleg_art, smallint) from public;

-- Festschreiben laeuft als security definer, weil es den Nummernkreis
-- fortschreiben muss, den die Anwendungsrolle nicht mehr anfassen darf. Damit
-- entfaellt der Schutz durch RLS - die Zugehoerigkeit wird deshalb hier
-- ausdruecklich geprueft, und zwar gegen auth.uid(), nicht gegen die Rolle.
create or replace function beleg_festschreiben(p_beleg uuid)
  returns text
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_beleg  beleg%rowtype;
  v_anzahl integer;
  v_nummer text;
begin
  select * into v_beleg from beleg where id = p_beleg for update;
  if not found then
    raise exception 'Beleg % existiert nicht', p_beleg using errcode = 'no_data_found';
  end if;

  -- Ohne diese Pruefung koennte jeder angemeldete Nutzer fremde Belege
  -- festschreiben, denn security definer umgeht die Mandanten-Policy.
  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.benutzer_id = (select auth.uid())
       and bb.betrieb_id  = v_beleg.betrieb_id
  ) then
    raise exception 'Kein Zugriff auf Beleg %', p_beleg using errcode = 'insufficient_privilege';
  end if;

  if v_beleg.status <> 'entwurf' then
    raise exception 'Beleg % ist bereits festgeschrieben (Nummer %)', p_beleg, v_beleg.nummer
      using errcode = 'restrict_violation';
  end if;

  select count(*) into v_anzahl
    from beleg_position where beleg_id = p_beleg and art not in ('text', 'titel');
  if v_anzahl = 0 then
    raise exception 'Beleg % hat keine abrechenbare Position', p_beleg
      using errcode = 'restrict_violation';
  end if;

  -- § 14 Abs. 4 Nr. 6 UStG
  if v_beleg.art in ('abschlagsrechnung', 'teilrechnung', 'schlussrechnung')
     and v_beleg.leistungsdatum is null then
    raise exception 'Rechnung % braucht ein Leistungsdatum (§ 14 Abs. 4 Nr. 6 UStG)', p_beleg
      using errcode = 'restrict_violation';
  end if;

  perform beleg_summen_neu(p_beleg);

  -- Das Jahr kommt aus dem Belegdatum, nicht aus current_date. Ein Beleg vom
  -- 31.12., der am 02.01. festgeschrieben wird, gehoert in den Kreis des alten
  -- Jahres.
  v_nummer := naechste_nummer(
    v_beleg.betrieb_id, v_beleg.art, extract(year from v_beleg.datum)::smallint
  );

  update beleg
     set nummer = v_nummer, status = 'festgeschrieben', festgeschrieben_am = now()
   where id = p_beleg;

  return v_nummer;
end $$;

-- Die Anwendungsrolle darf den Nummernkreis nur noch lesen.
revoke insert, update, delete, truncate on nummernkreis from authenticated;
grant  select on nummernkreis to authenticated;
grant  execute on function beleg_festschreiben(uuid) to authenticated;
grant  execute on function nummer_praefix(beleg_art) to authenticated;

-- Die Policy 'for all' passte nicht mehr zu den Rechten: lesen ja, schreiben nein.
drop policy nummernkreis_mandant on nummernkreis;
create policy nummernkreis_lesen on nummernkreis
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));
