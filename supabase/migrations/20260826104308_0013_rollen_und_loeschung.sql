-- Drei bestaetigte Befunde: fehlende Rollendurchsetzung, unerreichbare
-- Mandantenloeschung und Journal-Waisen.

-- ------------------------------------------------------------------------ 1 --
-- benutzer_betrieb.rolle existierte mit inhaber/buero/monteur, wurde aber von
-- keiner Policy gelesen. Jedes Konto im Betrieb hatte Vollzugriff - auch das
-- Monteurkonto auf dem Mobilgeraet, das am leichtesten abhandenkommt. Wer es
-- uebernahm, konnte den gesamten Kundenstamm mit Kalkulationsanteilen lesen und
-- die IBAN des Betriebs aendern, also die Bankverbindung auf allen kuenftigen
-- Rechnungen.
create or replace function meine_betriebe_schreibend()
  returns setof uuid
  language sql stable security definer
  set search_path = public, pg_temp
  as $$
    select bb.betrieb_id from benutzer_betrieb bb
     where bb.benutzer_id = (select auth.uid())
       and bb.rolle in ('inhaber', 'buero')
  $$;

create or replace function meine_betriebe_inhaber()
  returns setof uuid
  language sql stable security definer
  set search_path = public, pg_temp
  as $$
    select bb.betrieb_id from benutzer_betrieb bb
     where bb.benutzer_id = (select auth.uid())
       and bb.rolle = 'inhaber'
  $$;

revoke all on function meine_betriebe_schreibend() from public;
revoke all on function meine_betriebe_inhaber()    from public;
grant execute on function meine_betriebe_schreibend() to authenticated;
grant execute on function meine_betriebe_inhaber()    to authenticated;

-- Der Betriebsstammsatz traegt die IBAN und die Steuernummer. Lesen darf ihn
-- jeder im Betrieb, aendern nur der Inhaber.
drop policy betrieb_eigene on betrieb;
create policy betrieb_lesen on betrieb
  for select to authenticated
  using (id = any (array(select meine_betriebe())));
create policy betrieb_aendern on betrieb
  for update to authenticated
  using      (id = any (array(select meine_betriebe_inhaber())))
  with check (id = any (array(select meine_betriebe_inhaber())));

-- Kaufmaennische Daten: alle im Betrieb lesen, nur Inhaber und Buero schreiben.
do $$
declare t text;
begin
  foreach t in array array[
    'kunde', 'ansprechpartner', 'mitarbeiter', 'lieferant', 'artikel', 'projekt',
    'beleg', 'beleg_position', 'einsatz'
  ]
  loop
    execute format('drop policy %I on %I', t || '_mandant', t);
    execute format($f$
      create policy %I on %I for select to authenticated
        using (betrieb_id = any (array(select meine_betriebe())))
    $f$, t || '_lesen', t);
    execute format($f$
      create policy %I on %I for insert to authenticated
        with check (betrieb_id = any (array(select meine_betriebe_schreibend())))
    $f$, t || '_anlegen', t);
    execute format($f$
      create policy %I on %I for update to authenticated
        using      (betrieb_id = any (array(select meine_betriebe_schreibend())))
        with check (betrieb_id = any (array(select meine_betriebe_schreibend())))
    $f$, t || '_aendern', t);
    execute format($f$
      create policy %I on %I for delete to authenticated
        using (betrieb_id = any (array(select meine_betriebe_schreibend())))
    $f$, t || '_loeschen', t);
  end loop;
end $$;

-- Baustellendaten: hier muss der Monteur schreiben duerfen, sonst ist die App
-- auf der Baustelle nutzlos.
do $$
declare t text;
begin
  foreach t in array array['dokumentation', 'zeiteintrag']
  loop
    execute format('drop policy %I on %I', t || '_mandant', t);
    execute format($f$
      create policy %I on %I for all to authenticated
        using      (betrieb_id = any (array(select meine_betriebe())))
        with check (betrieb_id = any (array(select meine_betriebe())))
    $f$, t || '_mandant', t);
  end loop;
end $$;

-- ------------------------------------------------------------------------ 2 --
-- Jede Tabelle haengt per ON DELETE CASCADE am Betrieb, das Schema versprach
-- also die vollstaendige Loeschung eines Mandanten. Der BEFORE-DELETE-Trigger
-- auf beleg feuerte aber auch fuer die Kaskade und brach ab, sobald ein
-- einziger Beleg festgeschrieben war. Damit gab es nach der ersten Rechnung
-- keinen Weg mehr fuer Mandantenaustritt oder Loeschung nach Art. 17 DSGVO -
-- und der Aufrufer bekam eine Belegmeldung statt einer Aussage ueber den Betrieb.
--
-- Die Ausnahme ist eng gefasst: sie greift nur, wenn current_user der
-- Funktionseigentuemer ist. Innerhalb einer security-definer-Funktion trifft
-- das zu, fuer eine Anwendungsrolle nie - ein Nutzer kann den Schalter also
-- nicht selbst setzen und damit auch keinen einzelnen Beleg loeschen.
create or replace function loeschung_laeuft_fuer(p_betrieb uuid)
  returns boolean
  language plpgsql stable
  set search_path = public, pg_temp
  as $$
begin
  return current_user = 'postgres'
     and coalesce(current_setting('app.betrieb_loeschung', true), '') = p_betrieb::text;
end $$;

create or replace function beleg_nicht_loeschbar()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if loeschung_laeuft_fuer(old.betrieb_id) then
    return old;
  end if;
  if old.status <> 'entwurf' then
    raise exception
      'Beleg % ist festgeschrieben und nicht loeschbar (GoBD). Stattdessen stornieren.',
      coalesce(old.nummer, old.id::text) using errcode = 'restrict_violation';
  end if;
  return old;
end $$;

create or replace function position_unveraenderlich()
  returns trigger
  language plpgsql security definer
  set search_path = public, pg_temp
  as $$
declare
  v_status beleg_status;
  v_beleg  uuid;
begin
  if tg_op = 'DELETE' and loeschung_laeuft_fuer(old.betrieb_id) then
    return old;
  end if;
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

-- ------------------------------------------------------------------------ 3 --
-- journal traegt bewusst KEINEN Fremdschluessel auf betrieb: es muss die Zeilen
-- ueberleben, die es beschreibt. Genau dadurch blieben nach einer
-- Betriebsloeschung aber Waisenzeilen zurueck - mit vollstaendigen
-- vorher/nachher-Abbildern samt Kunden- und Mitarbeiterdaten, fuer niemanden
-- lesbar und durch den Anfuegen-Trigger auch nicht mehr entfernbar.
-- Die Loeschfunktion raeumt sie deshalb ausdruecklich mit ab.
create or replace function journal_ist_anfuegend()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if tg_op = 'DELETE' and loeschung_laeuft_fuer(old.betrieb_id) then
    return old;
  end if;
  raise exception
    'Das Journal ist anfuegend. % ist auf journal nicht zulaessig (GoBD, Unveraenderbarkeit).', tg_op
    using errcode = 'restrict_violation';
end $$;

-- Der einzige Weg, einen Mandanten vollstaendig zu entfernen.
create or replace function betrieb_loeschen(p_betrieb uuid)
  returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
begin
  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.benutzer_id = (select auth.uid())
       and bb.betrieb_id  = p_betrieb
       and bb.rolle       = 'inhaber'
  ) then
    raise exception 'Nur der Inhaber kann den Betrieb loeschen' using errcode = 'insufficient_privilege';
  end if;

  perform set_config('app.betrieb_loeschung', p_betrieb::text, true);  -- nur diese Transaktion
  delete from betrieb where id = p_betrieb;   -- raeumt per Kaskade alle Fachtabellen ab
  delete from journal where betrieb_id = p_betrieb;
  perform set_config('app.betrieb_loeschung', '', true);
end $$;

revoke all on function betrieb_loeschen(uuid) from public;
grant execute on function betrieb_loeschen(uuid) to authenticated;
