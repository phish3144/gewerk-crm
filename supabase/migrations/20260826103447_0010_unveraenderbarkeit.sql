-- Fuenf bestaetigte Befunde zur GoBD-Unveraenderbarkeit.

-- ------------------------------------------------------------------------ 0 --
-- Der Beleg hielt keine Kopie der Kundendaten. Aendert der Kunde spaeter seine
-- Anschrift oder USt-IdNr., aendert sich rueckwirkend auch jede laengst
-- festgeschriebene Rechnung - ohne Journaleintrag, weil kunde gar nicht
-- journalisiert wird. Dasselbe galt fuer Zahlungsziel und Skonto, die am Kunden
-- hingen. Beides gehoert zum Zeitpunkt der Festschreibung eingefroren.
alter table beleg
  add column kunde_name        text,
  add column kunde_strasse     text,
  add column kunde_plz         text,
  add column kunde_ort         text,
  add column kunde_ust_id      text,
  add column zahlungsziel_tage smallint,
  add column skonto_prozent    numeric(5,2),
  add column skonto_tage       smallint;

-- Eine festgeschriebene Rechnung ohne Namen des Leistungsempfaengers waere nach
-- § 14 Abs. 4 Nr. 1 UStG unvollstaendig.
alter table beleg add constraint beleg_kundenkopie_bei_festschreibung check (
  status = 'entwurf' or kunde_name is not null
);

-- ------------------------------------------------------------------------ 1 --
-- position_unveraenderlich() lief als security invoker. Sein
--   select status from beleg where id = ...
-- lief damit unter der RLS-Policy des Aufrufers. Bei einem Beleg, den der
-- Aufrufer nicht sehen darf, kam NULL zurueck - und die Bedingung
--   if v_status is not null and v_status <> 'entwurf'
-- griff nicht. Die GoBD-Sperre wurde also durch genau die Luecke ausgehebelt,
-- die sie haette auffangen sollen. Zusaetzlich prueft die Funktion jetzt BEIDE
-- Belege: sonst laesst sich eine Position aus einer festgeschriebenen Rechnung
-- heraus in einen Entwurf umhaengen.
create or replace function position_unveraenderlich()
  returns trigger
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_status beleg_status;
  v_beleg  uuid;
begin
  foreach v_beleg in array array_remove(array[old.beleg_id, new.beleg_id], null)
  loop
    select status into v_status from beleg where id = v_beleg;
    if v_status is null then
      raise exception 'Beleg % existiert nicht', v_beleg using errcode = 'foreign_key_violation';
    end if;
    if v_status <> 'entwurf' then
      raise exception
        'Positionen des festgeschriebenen Belegs % sind unveraenderlich (GoBD).', v_beleg
        using errcode = 'restrict_violation';
    end if;
  end loop;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

-- ------------------------------------------------------------------------ 2 --
-- beleg_unveraenderlich() liess status und storniert_durch voellig frei. Damit
-- liess sich ein festgeschriebener Beleg auf 'entwurf' zuruecksetzen - und war
-- danach wieder vollstaendig aenderbar. Der Stornoverweis war beliebig
-- umsetzbar und wieder loeschbar.
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

  -- Der Stornoverweis wird einmal gesetzt und nie wieder veraendert.
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
  then
    raise exception
      'Beleg % ist festgeschrieben und inhaltlich unveraenderlich (GoBD). Korrektur nur ueber Storno und Neuausstellung.',
      coalesce(old.nummer, old.id::text) using errcode = 'restrict_violation';
  end if;

  return new;
end $$;

-- ------------------------------------------------------------------------ 3 --
-- Festschreiben friert die Kundendaten und Zahlungskonditionen ein. Ab hier
-- gilt, was auf dem Beleg steht, nicht was im Kundenstamm steht.
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
begin
  select * into v_beleg from beleg where id = p_beleg for update;
  if not found then
    raise exception 'Beleg % existiert nicht', p_beleg using errcode = 'no_data_found';
  end if;

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

  if v_beleg.art in ('abschlagsrechnung', 'teilrechnung', 'schlussrechnung')
     and v_beleg.leistungsdatum is null then
    raise exception 'Rechnung % braucht ein Leistungsdatum (§ 14 Abs. 4 Nr. 6 UStG)', p_beleg
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
         skonto_tage        = v_kunde.skonto_tage
   where id = p_beleg;

  return v_nummer;
end $$;

grant execute on function beleg_festschreiben(uuid) to authenticated;
