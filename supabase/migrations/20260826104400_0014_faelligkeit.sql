-- Faelligkeit einfrieren und das Belegdatum beim Festschreiben pruefen.

create or replace function beleg_festschreiben(p_beleg uuid)
  returns text
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_beleg  beleg%rowtype;
  v_kunde  kunde%rowtype;
  v_anzahl integer;
  v_nummer text;
  v_heute  date := (now() at time zone 'Europe/Berlin')::date;
begin
  select * into v_beleg from beleg where id = p_beleg for update;
  if not found then
    raise exception 'Beleg % existiert nicht', p_beleg using errcode = 'no_data_found';
  end if;

  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.benutzer_id = (select auth.uid())
       and bb.betrieb_id  = v_beleg.betrieb_id
       and bb.rolle in ('inhaber', 'buero')
  ) then
    raise exception 'Kein Schreibzugriff auf Beleg %', p_beleg using errcode = 'insufficient_privilege';
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

  if v_beleg.art in ('abschlagsrechnung', 'teilrechnung', 'schlussrechnung')
     and v_beleg.leistungsdatum is null then
    raise exception 'Rechnung % braucht ein Leistungsdatum (§ 14 Abs. 4 Nr. 6 UStG)', p_beleg
      using errcode = 'restrict_violation';
  end if;

  -- Ein Beleg aus der Zukunft ergibt keinen Sinn und verschoebe Umsatz in eine
  -- kuenftige Periode. Rueckdatierung faengt zusaetzlich die CHECK-Bedingung
  -- aus 0012 ab, sobald festgeschrieben_am gesetzt ist.
  if v_beleg.datum > v_heute then
    raise exception 'Belegdatum % liegt in der Zukunft (heute %)', v_beleg.datum, v_heute
      using errcode = 'restrict_violation';
  end if;

  select * into v_kunde from kunde where id = v_beleg.kunde_id;

  perform beleg_summen_neu(p_beleg);
  v_nummer := naechste_nummer(
    v_beleg.betrieb_id, v_beleg.art, extract(year from v_beleg.datum)::smallint
  );

  update beleg
     set nummer             = v_nummer,
         status             = 'festgeschrieben',
         festgeschrieben_am = now(),
         kunde_name         = v_kunde.name,
         kunde_strasse      = v_kunde.strasse,
         kunde_plz          = v_kunde.plz,
         kunde_ort          = v_kunde.ort,
         kunde_ust_id       = v_kunde.ust_id,
         zahlungsziel_tage  = v_kunde.zahlungsziel_tage,
         skonto_prozent     = v_kunde.skonto_prozent,
         skonto_tage        = v_kunde.skonto_tage,
         faelligkeit_am     = v_beleg.datum + coalesce(v_kunde.zahlungsziel_tage, 14)
   where id = p_beleg;

  return v_nummer;
end $$;

grant execute on function beleg_festschreiben(uuid) to authenticated;

-- faelligkeit_am gehoert zu den eingefrorenen Feldern.
create or replace function beleg_unveraenderlich()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if old.status = 'entwurf' then
    return new;
  end if;

  if new.status = 'entwurf' then
    raise exception
      'Beleg % ist festgeschrieben und kann nicht in den Entwurf zurueck (GoBD).',
      coalesce(old.nummer, old.id::text) using errcode = 'restrict_violation';
  end if;

  if old.storniert_durch is not null
     and new.storniert_durch is distinct from old.storniert_durch then
    raise exception 'Der Stornoverweis auf Beleg % steht bereits fest.',
      coalesce(old.nummer, old.id::text) using errcode = 'restrict_violation';
  end if;

  if new.status = 'storniert' and new.storniert_durch is null then
    raise exception 'Storno von Beleg % ohne Verweis auf den Stornobeleg.',
      coalesce(old.nummer, old.id::text) using errcode = 'restrict_violation';
  end if;

  if new.betrieb_id         is distinct from old.betrieb_id
  or new.kunde_id           is distinct from old.kunde_id
  or new.projekt_id         is distinct from old.projekt_id
  or new.art                is distinct from old.art
  or new.nummer             is distinct from old.nummer
  or new.datum              is distinct from old.datum
  or new.leistungsdatum     is distinct from old.leistungsdatum
  or new.betreff            is distinct from old.betreff
  or new.netto              is distinct from old.netto
  or new.steuer             is distinct from old.steuer
  or new.brutto             is distinct from old.brutto
  or new.vorgaenger_id      is distinct from old.vorgaenger_id
  or new.festgeschrieben_am is distinct from old.festgeschrieben_am
  or new.erstellt_von       is distinct from old.erstellt_von
  or new.erstellt_am        is distinct from old.erstellt_am
  or new.kunde_name         is distinct from old.kunde_name
  or new.kunde_strasse      is distinct from old.kunde_strasse
  or new.kunde_plz          is distinct from old.kunde_plz
  or new.kunde_ort          is distinct from old.kunde_ort
  or new.kunde_ust_id       is distinct from old.kunde_ust_id
  or new.zahlungsziel_tage  is distinct from old.zahlungsziel_tage
  or new.skonto_prozent     is distinct from old.skonto_prozent
  or new.skonto_tage        is distinct from old.skonto_tage
  or new.faelligkeit_am     is distinct from old.faelligkeit_am
  then
    raise exception
      'Beleg % ist festgeschrieben und inhaltlich unveraenderlich (GoBD). Korrektur nur ueber Storno und Neuausstellung.',
      coalesce(old.nummer, old.id::text) using errcode = 'restrict_violation';
  end if;

  return new;
end $$;
