-- Der Nachtragswaechter, Teil 2: Handeln.
--
-- Aus der Meldung wird in einem Zug ein abrechenbarer Nachtrag: Positionen aus
-- den Ist-Mengen, Bezug auf den Hauptauftrag in vorgaenger_id, die betroffenen
-- Buchungen wandern aus "ungeklaert" heraus. Dazu die Bedenkenanzeige nach
-- § 4 Abs. 3 VOB/B, die nach dem Versand nicht mehr aenderbar ist.

-- ------------------------------------------------------------- Nummernkreis --
-- NA- wie Nachtrag. Der Kreis selbst entsteht beim ersten Festschreiben.
create or replace function nummer_praefix(p_art beleg_art)
  returns text
  language sql
  immutable
  set search_path = public, pg_temp
  as $$
    select case p_art
      when 'angebot'           then 'AN-'
      when 'auftrag'           then 'AU-'
      when 'nachtrag'          then 'NA-'
      when 'abschlagsrechnung' then 'AR-'
      when 'teilrechnung'      then 'TR-'
      when 'schlussrechnung'   then 'RE-'
      when 'gutschrift'        then 'GU-'
      when 'storno'            then 'ST-'
    end
  $$;
revoke all on function nummer_praefix(beleg_art) from public, anon, authenticated;
grant execute on function nummer_praefix(beleg_art) to authenticated;

-- ------------------------------------------------------- Preispflicht -------
-- Ab 110 % ist laut BGH nicht mehr die urspruengliche Preisermittlung
-- massgeblich, sondern die tatsaechlich erforderlichen Kosten der Mehrmenge.
-- Die Anwendung darf den alten Einheitspreis also nicht stillschweigend
-- fortschreiben - deshalb entsteht jede Nachtragsposition mit Preis null, und
-- festschreiben laesst sich der Nachtrag erst, wenn jemand den Preis gesetzt
-- hat. Der Zwang steht in der Datenbank, nicht im Formular.
--
-- Eigener Trigger statt Aenderung an beleg_festschreiben: die Funktion ist
-- durchgepruefte Stelle, und ein Abbruch hier rollt die Transaktion samt
-- Nummernvergabe zurueck - es entsteht keine Luecke im Kreis.
create or replace function nachtrag_braucht_preise()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare v_offen integer;
begin
  if new.art <> 'nachtrag' or old.status <> 'entwurf' or new.status = 'entwurf' then
    return new;
  end if;

  select count(*) into v_offen
    from beleg_position p
   where p.beleg_id = new.id
     and p.art not in ('text', 'titel')
     and p.einzelpreis = 0;

  if v_offen > 0 then
    raise exception
      '% Nachtragsposition(en) ohne Preis. Ab 110 %% der Sollmenge zaehlen die '
      'tatsaechlich erforderlichen Kosten der Mehrmenge, nicht der alte '
      'Einheitspreis (BGH zu § 2 Abs. 3 Nr. 2 VOB/B).', v_offen
      using errcode = 'restrict_violation';
  end if;
  return new;
end $$;

create trigger trg_nachtrag_braucht_preise
  before update on beleg
  for each row execute function nachtrag_braucht_preise();

-- ---------------------------------------------------------- Bedenkenanzeige --
-- § 4 Abs. 3 VOB/B: Bedenken gegen die vorgesehene Art der Ausfuehrung sind
-- dem Auftraggeber unverzueglich - moeglichst vor Beginn der Arbeiten -
-- schriftlich mitzuteilen. Wer das versaeumt, haftet.
--
-- Der Datensatz ist nach dem Versand eingefroren. Eine nachtraeglich
-- "praezisierte" Bedenkenanzeige ist im Streitfall wertlos; ihr ganzer Wert
-- liegt darin, dass sie zu einem belegbaren Zeitpunkt so und nicht anders
-- hinausgegangen ist.
create table bedenkenanzeige (
  id           uuid primary key default gen_random_uuid(),
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  projekt_id   uuid not null,
  -- Der Nachtrag, auf den sie sich bezieht. Optional: Bedenken koennen auch
  -- ohne Nachtrag angezeigt werden - das ist sogar der Regelfall.
  nachtrag_id  uuid,
  betreff      text not null,
  sachverhalt  text not null,
  -- Frei, weil die Norm keine Form vorschreibt ausser der Schriftform.
  folgen       text,
  erstellt_am  timestamptz not null default now(),
  erstellt_von uuid not null references benutzer(id) on delete restrict,

  versendet_am  timestamptz,
  versendet_wie text,
  versendet_an  text,

  constraint bedenken_betreff_nicht_leer     check (btrim(betreff) <> ''),
  constraint bedenken_sachverhalt_nicht_leer check (btrim(sachverhalt) <> ''),
  -- Versendet heisst: alle drei Angaben. "Irgendwann per irgendwas" ist kein
  -- Nachweis.
  -- coalesce ist hier nicht Bequemlichkeit, sondern noetig: btrim(null) <> ''
  -- ergibt NULL, und eine Pruefregel gilt als erfuellt, sobald ihr Ausdruck
  -- NULL ist. Ohne coalesce liesse sich versendet_am allein setzen - genau der
  -- Fall, den die Regel verhindern soll.
  constraint bedenken_versand_vollstaendig check (
    (versendet_am is null and versendet_wie is null and versendet_an is null)
    or (versendet_am is not null
        and coalesce(btrim(versendet_wie), '') <> ''
        and coalesce(btrim(versendet_an), '')  <> '')
  ),
  constraint bedenkenanzeige_mandant_id unique (betrieb_id, id)
);

alter table bedenkenanzeige add constraint bedenkenanzeige_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id) on delete cascade;
alter table bedenkenanzeige add constraint bedenkenanzeige_nachtrag_fk
  foreign key (betrieb_id, nachtrag_id) references beleg (betrieb_id, id)
  on delete set null (nachtrag_id);

create index bedenkenanzeige_projekt_fk_idx  on bedenkenanzeige (betrieb_id, projekt_id, erstellt_am desc);
create index bedenkenanzeige_nachtrag_fk_idx on bedenkenanzeige (betrieb_id, nachtrag_id);
create index bedenkenanzeige_erstellt_von_idx on bedenkenanzeige (erstellt_von);

-- Die Fotos zur Bedenkenanzeige: dieselben Nachweise, die von der Baustelle
-- kamen. Kopiert wird nichts, verwiesen schon.
create table bedenken_nachweis (
  betrieb_id       uuid not null,
  bedenkenanzeige_id uuid not null,
  dokumentation_id uuid not null,
  -- betrieb_id vorn: der Schluessel deckt damit zugleich den zusammengesetzten
  -- Fremdschluessel auf die Anzeige. Ohne das liest jedes Loeschen einer
  -- Bedenkenanzeige diese Tabelle vollstaendig - Test 03 haelt das nach.
  primary key (betrieb_id, bedenkenanzeige_id, dokumentation_id),
  constraint bedenken_nachweis_anzeige_fk
    foreign key (betrieb_id, bedenkenanzeige_id) references bedenkenanzeige (betrieb_id, id)
    on delete cascade,
  constraint bedenken_nachweis_doku_fk
    foreign key (betrieb_id, dokumentation_id) references dokumentation (betrieb_id, id)
    on delete cascade
);
create index bedenken_nachweis_doku_idx on bedenken_nachweis (betrieb_id, dokumentation_id);

create or replace function bedenken_unveraenderlich()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  if old.versendet_am is null then
    return new;   -- Entwurf: alles darf sich noch bewegen.
  end if;

  if new.betreff      is distinct from old.betreff
  or new.sachverhalt  is distinct from old.sachverhalt
  or new.folgen       is distinct from old.folgen
  or new.projekt_id   is distinct from old.projekt_id
  or new.nachtrag_id  is distinct from old.nachtrag_id
  or new.betrieb_id   is distinct from old.betrieb_id
  or new.versendet_am is distinct from old.versendet_am
  or new.versendet_wie is distinct from old.versendet_wie
  or new.versendet_an  is distinct from old.versendet_an then
    raise exception
      'Die Bedenkenanzeige ist am % versendet worden und damit unveraenderlich. '
      'Eine nachtraeglich geaenderte Anzeige ist im Streitfall wertlos.',
      to_char(old.versendet_am, 'DD.MM.YYYY')
      using errcode = 'restrict_violation';
  end if;
  return new;
end $$;

create trigger trg_bedenken_unveraenderlich
  before update on bedenkenanzeige
  for each row execute function bedenken_unveraenderlich();

-- Geloescht wird eine versendete Anzeige ebenfalls nicht.
create or replace function bedenken_nicht_loeschbar()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  -- Beim Abraeumen eines ganzen Mandanten laeuft die Kaskade durch; dort setzt
  -- betrieb_loeschen dieselbe Kennung wie fuer das Journal in 0011.
  if coalesce(current_setting('app.betrieb_loeschung', true), '') = old.betrieb_id::text then
    return old;
  end if;
  if old.versendet_am is not null then
    raise exception
      'Die Bedenkenanzeige vom % ist versendet und wird nicht geloescht.',
      to_char(old.versendet_am, 'DD.MM.YYYY')
      using errcode = 'restrict_violation';
  end if;
  return old;
end $$;

create trigger trg_bedenken_nicht_loeschbar
  before delete on bedenkenanzeige
  for each row execute function bedenken_nicht_loeschbar();

-- ------------------------------------------------------ Leistungsstand ------
-- Ein festgeschriebener Nachtrag ist beauftragt. Seine Positionen gehoeren
-- deshalb in den Soll-Bestand - sonst meldete der Waechter die Mehrmenge, die
-- er selbst gerade zum Nachtrag gemacht hat, gleich wieder.
create or replace view leistungsstand with (security_invoker = true) as
with zeit as (
  select z.betrieb_id, z.position_id,
         sum(extract(epoch from (z.ende - z.beginn)) / 3600.0
             - z.pause_minuten / 60.0)::numeric(14,4) as stunden
    from zeiteintrag z
   where z.position_id is not null and z.ende is not null
   group by z.betrieb_id, z.position_id
),
material as (
  select m.betrieb_id, m.position_id, einheit_gruppe(m.einheit) as gruppe,
         sum(m.menge) as menge
    from materialentnahme m
   where m.position_id is not null
   group by m.betrieb_id, m.position_id, einheit_gruppe(m.einheit)
)
select
  p.betrieb_id,
  p.id                      as position_id,
  p.beleg_id,
  b.projekt_id,
  p.position_nr,
  p.bezeichnung,
  p.einheit,
  einheit_gruppe(p.einheit) as gruppe,
  p.menge                   as soll_menge,
  p.einzelpreis,
  case
    when einheit_gruppe(p.einheit) is null       then null
    when einheit_gruppe(p.einheit) = 'stunden'   then coalesce(z.stunden, 0)
    else coalesce(m.menge, 0)
  end                       as ist_menge
from beleg_position p
join beleg b on b.betrieb_id = p.betrieb_id and b.id = p.beleg_id
left join zeit z
  on z.betrieb_id = p.betrieb_id and z.position_id = p.id
left join material m
  on m.betrieb_id = p.betrieb_id and m.position_id = p.id
 and m.gruppe = einheit_gruppe(p.einheit)
where b.art in ('auftrag', 'nachtrag')
  and p.art in ('leistung', 'material', 'lohn', 'fremdleistung');

grant select on leistungsstand to authenticated;

-- ------------------------------------------------------ Nachtrag anlegen ----
-- Aus Meldungen wird ein Nachtragsentwurf. In einem Aufruf, weil der Weg von
-- der Meldung zum abrechenbaren Nachtrag unter zwei Minuten dauern soll und
-- nicht acht Formulare.
--
-- security invoker: jede Einfuegung laeuft durch die Policies. Ein fremdes
-- Projekt liefert schon beim Lesen nichts, ein fremder Betrieb scheitert an
-- der with-check-Klausel. Eine definer-Funktion muesste die Zugehoerigkeit
-- selbst pruefen und waere die schwaechere Loesung.
create or replace function nachtrag_anlegen(p_projekt uuid, p_meldungen jsonb)
  returns uuid
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_projekt   record;
  v_auftrag   uuid;
  v_nachtrag  uuid;
  v_nr        integer := 0;
  m           jsonb;
  v_meldung   record;
  v_position  uuid;
begin
  select p.id, p.betrieb_id, p.kunde_id into v_projekt
    from projekt p where p.id = p_projekt;
  if not found then
    raise exception 'Baustelle % nicht gefunden', p_projekt using errcode = 'no_data_found';
  end if;

  if jsonb_typeof(p_meldungen) <> 'array' or jsonb_array_length(p_meldungen) = 0 then
    raise exception 'Ohne Meldung kein Nachtrag' using errcode = 'restrict_violation';
  end if;

  -- Der Hauptauftrag ist der Bezug. Gibt es keinen, bleibt vorgaenger_id leer -
  -- ein Nachtrag ohne schriftlichen Hauptauftrag ist unschoen, aber Alltag.
  select b.id into v_auftrag
    from beleg b
   where b.projekt_id = p_projekt and b.art = 'auftrag' and b.status <> 'entwurf'
   order by b.festgeschrieben_am desc
   limit 1;

  insert into beleg (betrieb_id, kunde_id, projekt_id, art, vorgaenger_id, datum,
                     betreff, erstellt_von)
  values (v_projekt.betrieb_id, v_projekt.kunde_id, p_projekt, 'nachtrag', v_auftrag,
          current_date, 'Nachtrag aus ungeklaerter Leistung', (select auth.uid()))
  returning id into v_nachtrag;

  for m in select * from jsonb_array_elements(p_meldungen)
  loop
    select * into v_meldung
      from ungeklaerte_leistung u
     where u.gegenstand    = (m ->> 'gegenstand')
       and u.gegenstand_id = (m ->> 'gegenstand_id')::uuid
       and u.projekt_id    = p_projekt;
    if not found then
      raise exception 'Meldung % / % gehoert nicht zu dieser Baustelle oder ist bereits geklaert',
        m ->> 'gegenstand', m ->> 'gegenstand_id' using errcode = 'no_data_found';
    end if;

    v_nr := v_nr + 1;

    -- Einzelpreis bewusst null: die tatsaechlich erforderlichen Kosten sind
    -- einzutragen, nicht der fortgeschriebene alte Preis. Ohne sie laesst der
    -- Trigger oben das Festschreiben nicht zu.
    insert into beleg_position (betrieb_id, beleg_id, position_nr, art, bezeichnung,
                                menge, einheit, einzelpreis)
    values (v_projekt.betrieb_id, v_nachtrag, v_nr,
            (case when v_meldung.gegenstand = 'materialentnahme' then 'material'
                  else 'leistung' end)::position_art,
            v_meldung.bezeichnung, v_meldung.menge, v_meldung.einheit, 0)
    returning id into v_position;

    -- Die Buchung haengt jetzt an der Nachtragsposition und ist damit
    -- beauftragt. Bei einer Mehrmenge gibt es keine einzelne Buchung - dort
    -- traegt allein der Klaerungsvermerk.
    if v_meldung.gegenstand = 'zeiteintrag' then
      update zeiteintrag set position_id = v_position where id = v_meldung.gegenstand_id;
    elsif v_meldung.gegenstand = 'materialentnahme' then
      update materialentnahme set position_id = v_position where id = v_meldung.gegenstand_id;
    end if;

    insert into klaerung (betrieb_id, gegenstand, gegenstand_id, grund, nachtrag_id, geklaert_von)
    values (v_projekt.betrieb_id, v_meldung.gegenstand, v_meldung.gegenstand_id,
            'In den Nachtrag uebernommen', v_nachtrag, (select auth.uid()));
  end loop;

  return v_nachtrag;
end $$;

revoke all on function nachtrag_anlegen(uuid, jsonb) from public, anon, authenticated;
grant execute on function nachtrag_anlegen(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------------ RLS ----
alter table bedenkenanzeige enable row level security;
create policy bedenkenanzeige_lesen on bedenkenanzeige
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));
create policy bedenkenanzeige_schreiben on bedenkenanzeige
  for all to authenticated
  using      (betrieb_id = any (array(select meine_betriebe_schreibend())))
  with check (betrieb_id = any (array(select meine_betriebe_schreibend())));

alter table bedenken_nachweis enable row level security;
create policy bedenken_nachweis_lesen on bedenken_nachweis
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));
create policy bedenken_nachweis_schreiben on bedenken_nachweis
  for all to authenticated
  using      (betrieb_id = any (array(select meine_betriebe_schreibend())))
  with check (betrieb_id = any (array(select meine_betriebe_schreibend())));

-- ---------------------------------------------------------------- Journal --
create trigger trg_journal_bedenkenanzeige
  after insert or update or delete on bedenkenanzeige
  for each row execute function journal_schreiben();

-- ------------------------------------------------------------- Rechte -----
grant select, insert, update, delete on bedenkenanzeige   to authenticated;
grant select, insert, delete         on bedenken_nachweis to authenticated;

-- Triggerfunktionen ruft nur der Trigger auf, nie eine Nutzerin. Der
-- Standard fuer Funktionen ist EXECUTE fuer PUBLIC - seit 0017 wird das
-- ausgeschrieben entzogen, und Test 09 haelt die Liste nach.
revoke all on function nachtrag_braucht_preise()   from public, anon, authenticated;
revoke all on function bedenken_unveraenderlich()  from public, anon, authenticated;
revoke all on function bedenken_nicht_loeschbar()  from public, anon, authenticated;
