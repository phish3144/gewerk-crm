-- Der Nachtragswaechter, Teil 1: Erkennen.
--
-- Das ist der Kern des Alleinstellungsmerkmals. Jede Wettbewerbsanwendung
-- erfasst Zeiten und schreibt Rechnungen; keine sagt dem Betrieb am selben
-- Abend, dass heute fuer 1.240 Euro gearbeitet wurde, was niemand beauftragt
-- hat. Genau das entsteht hier - und zwar in der Datenbank, nicht in der
-- Oberflaeche: was nur die Anwendung durchsetzt, setzt ein direkter Zugriff
-- ausser Kraft.
--
-- Drei Regeln:
--   1. Zeitbuchung ohne Position       - schlicht nicht beauftragt
--   2. Materialentnahme ohne Position  - dito
--   3. Ist-Menge ueber 110 % der Soll-Menge   - § 2 Abs. 3 Nr. 2 VOB/B
--
-- Regel 3 laeuft nur, wo die Einheiten vergleichbar sind. Aus Stunden folgt
-- keine Flaeche; eine Position in m² ist aus Buchungen nicht ableitbar und
-- bleibt deshalb ausdruecklich aussen vor, statt eine Scheinzahl zu liefern.

-- ------------------------------------------------------- Materialentnahme --
-- Wie zeiteintrag: die Kennung kommt vom Geraet, damit ein doppelt gesendeter
-- Eintrag aus der Offline-Warteschlange keinen zweiten Datensatz erzeugt.
create table materialentnahme (
  id           uuid primary key,
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  projekt_id   uuid not null references projekt(id) on delete cascade,
  -- Entweder ein Artikel aus dem Stamm oder eine freie Bezeichnung. Auf der
  -- Baustelle ist beides ueblich, und der Zwang zum Stammartikel waere der
  -- sichere Weg, dass gar nichts erfasst wird.
  artikel_id   uuid references artikel(id) on delete set null,
  bezeichnung  text,
  menge        numeric(14,4) not null,
  einheit      text not null default 'Stk',
  -- Der Einkaufspreis wird zum Zeitpunkt der Entnahme kopiert, nicht spaeter
  -- aus dem Artikelstamm nachgeschlagen: der Stammpreis aendert sich, der
  -- Wert der Entnahme nicht.
  ek_preis     numeric(14,2) not null default 0,
  position_id  uuid references beleg_position(id) on delete set null,
  -- Der Nachweis zur Buchung ohne Position. Siehe Nachweispflicht unten.
  nachweis_id  uuid references dokumentation(id) on delete set null,
  erfasst_am   timestamptz not null,
  erfasst_von  uuid not null references mitarbeiter(id) on delete restrict,
  gebucht_am   timestamptz not null default now(),
  constraint material_menge_positiv check (menge > 0),
  constraint material_ek_nicht_negativ check (ek_preis >= 0),
  constraint material_benannt check (artikel_id is not null or bezeichnung is not null)
);

-- ------------------------------------------------------------- Klaerung ----
-- Eine Meldung verschwindet nicht durch Wegsehen, sondern durch eine
-- Begruendung. Die Begruendung ist der eigentliche Wert: sechs Monate spaeter
-- steht dort, warum diese vier Stunden niemand berechnet hat.
--
-- Eigene Tabelle statt Spalten auf den Buchungen: die dritte Regel haengt an
-- einer Position, nicht an einer Buchung, und beleg_position ist nach der
-- Festschreibung unveraenderlich. Ein Klaerungsvermerk darf daran nichts
-- aendern muessen.
create table klaerung (
  id            uuid primary key default gen_random_uuid(),
  betrieb_id    uuid not null references betrieb(id) on delete cascade,
  gegenstand    text not null,
  gegenstand_id uuid not null,
  grund         text not null,
  -- Wird in Schritt 7 gefuellt, wenn aus der Meldung ein Nachtrag wird.
  nachtrag_id   uuid references beleg(id) on delete set null,
  geklaert_am   timestamptz not null default now(),
  geklaert_von  uuid not null references benutzer(id) on delete restrict,
  constraint klaerung_gegenstand_bekannt check (
    gegenstand in ('zeiteintrag', 'materialentnahme', 'position_mehrmenge')
  ),
  constraint klaerung_grund_nicht_leer check (btrim(grund) <> ''),
  unique (betrieb_id, gegenstand, gegenstand_id)
);

-- ------------------------------------------- Mandantenbindung, strukturell --
-- Dasselbe Muster wie in 0008: jeder Fremdschluessel traegt die betrieb_id
-- mit. Ein mandantenuebergreifender Verweis ist damit nicht verboten, sondern
-- nicht formulierbar.
alter table dokumentation     add constraint dokumentation_mandant_id     unique (betrieb_id, id);
alter table materialentnahme  add constraint materialentnahme_mandant_id  unique (betrieb_id, id);

alter table materialentnahme drop constraint materialentnahme_projekt_id_fkey;
alter table materialentnahme add  constraint materialentnahme_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id) on delete cascade;

alter table materialentnahme drop constraint materialentnahme_artikel_id_fkey;
alter table materialentnahme add  constraint materialentnahme_artikel_fk
  foreign key (betrieb_id, artikel_id) references artikel (betrieb_id, id)
  on delete set null (artikel_id);

alter table materialentnahme drop constraint materialentnahme_position_id_fkey;
alter table materialentnahme add  constraint materialentnahme_position_fk
  foreign key (betrieb_id, position_id) references beleg_position (betrieb_id, id)
  on delete set null (position_id);

alter table materialentnahme drop constraint materialentnahme_nachweis_id_fkey;
alter table materialentnahme add  constraint materialentnahme_nachweis_fk
  foreign key (betrieb_id, nachweis_id) references dokumentation (betrieb_id, id)
  on delete set null (nachweis_id);

alter table materialentnahme drop constraint materialentnahme_erfasst_von_fkey;
alter table materialentnahme add  constraint materialentnahme_erfasst_von_fk
  foreign key (betrieb_id, erfasst_von) references mitarbeiter (betrieb_id, id) on delete restrict;

alter table klaerung drop constraint klaerung_nachtrag_id_fkey;
alter table klaerung add  constraint klaerung_nachtrag_fk
  foreign key (betrieb_id, nachtrag_id) references beleg (betrieb_id, id)
  on delete set null (nachtrag_id);

-- --------------------------------------------------------- Nachweispflicht --
-- Wer "keine passende Position" waehlt, muss ein Foto oder eine Notiz
-- mitgeben. Auf der Baustelle kostet das zehn Sekunden; vier Wochen spaeter
-- ist es nicht mehr zu beschaffen, und ohne Nachweis ist der Nachtrag im
-- Streitfall nichts wert.
alter table zeiteintrag add column nachweis_id uuid;
alter table zeiteintrag add constraint zeiteintrag_nachweis_fk
  foreign key (betrieb_id, nachweis_id) references dokumentation (betrieb_id, id)
  on delete set null (nachweis_id);

-- NOT VALID mit Absicht: die Regel gilt ab jetzt, nicht rueckwirkend. Bereits
-- erfasste Zeiten aus der Zeit vor dieser Migration haben keinen Nachweis und
-- sollen deshalb nicht nachtraeglich unzulaessig werden - eine Validierung
-- wuerde beim Einspielen abbrechen und die Migration unbrauchbar machen.
-- Fuer jede neue und jede geaenderte Zeile prueft Postgres trotzdem.
alter table zeiteintrag add constraint zeit_ohne_position_braucht_nachweis
  check (position_id is not null or nachweis_id is not null) not valid;

alter table materialentnahme add constraint material_ohne_position_braucht_nachweis
  check (position_id is not null or nachweis_id is not null);

-- ---------------------------------------------------------------- Indizes --
-- Nach dem Muster aus 0018: jeder zusammengesetzte Fremdschluessel bekommt
-- seinen deckenden Index, sonst liest jedes Loeschen des Elternsatzes die
-- Kindtabelle vollstaendig.
create index materialentnahme_projekt_fk_idx
  on materialentnahme (betrieb_id, projekt_id, erfasst_am desc);
create index materialentnahme_artikel_fk_idx
  on materialentnahme (betrieb_id, artikel_id);
create index materialentnahme_position_fk_idx
  on materialentnahme (betrieb_id, position_id);
create index materialentnahme_nachweis_fk_idx
  on materialentnahme (betrieb_id, nachweis_id);
create index materialentnahme_erfasst_von_fk_idx
  on materialentnahme (betrieb_id, erfasst_von);
-- Die Abfrage der Buerooansicht: alles ohne Position.
create index materialentnahme_ohne_position_idx
  on materialentnahme (betrieb_id, projekt_id) where position_id is null;

create index zeiteintrag_nachweis_fk_idx on zeiteintrag (betrieb_id, nachweis_id);

create index klaerung_nachtrag_fk_idx on klaerung (betrieb_id, nachtrag_id);
create index klaerung_geklaert_von_idx on klaerung (geklaert_von);

-- ------------------------------------------------------------- Einheiten ---
-- Regel 3 vergleicht Ist gegen Soll. Das geht nur, wenn beide Seiten dieselbe
-- Groesse messen. "Std" und "h" sind dieselbe Groesse, "m²" und "Stk" sind es
-- nicht - und aus Stunden folgt keine Flaeche. Was hier NULL liefert, ist aus
-- Buchungen nicht ableitbar und wird von Regel 3 ausgenommen; die Oberflaeche
-- sagt das auch.
create or replace function einheit_gruppe(p_einheit text)
  returns text
  language sql
  immutable
  set search_path = public, pg_temp
  as $$
  select case lower(btrim(coalesce(p_einheit, '')))
    when 'std'      then 'stunden'
    when 'std.'     then 'stunden'
    when 'h'        then 'stunden'
    when 'stunde'   then 'stunden'
    when 'stunden'  then 'stunden'
    when 'akh'      then 'stunden'
    when 'stk'      then 'stueck'
    when 'stk.'     then 'stueck'
    when 'st'       then 'stueck'
    when 'stück'    then 'stueck'
    when 'stueck'   then 'stueck'
    when 'm'        then 'meter'
    when 'lfm'      then 'meter'
    when 'meter'    then 'meter'
    when 'kg'       then 'kilogramm'
    when 'kilogramm' then 'kilogramm'
    when 'l'        then 'liter'
    when 'liter'    then 'liter'
    else null       -- m², m³, pauschal, psch: nicht aus Buchungen ableitbar
  end $$;

-- --------------------------------------------------------- Leistungsstand --
-- Soll gegen Ist je Auftragsposition. Grundlage von Regel 3 und spaeter der
-- Abschlagsautomatik nach § 632a BGB.
--
-- security_invoker: ohne das laeuft die Sicht mit den Rechten ihrer
-- Eigentuemerin und umgeht saemtliche Policies. Bei Supabase ist das die
-- haeufigste stille Datenlecke ueberhaupt.
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
where b.art = 'auftrag'
  and p.art in ('leistung', 'material', 'lohn', 'fremdleistung');

-- ------------------------------------------------------- Ungeklaerte Sicht --
-- Die drei Regeln in einer Sicht, mit Betrag in Euro. Nicht "7 Meldungen",
-- sondern "1.240 Euro nicht beauftragt" - die Zahl ist die Botschaft. Zu viele
-- Meldungen sind so schlecht wie keine.
create or replace view ungeklaerte_leistung with (security_invoker = true) as

-- Regel 1: Zeitbuchung ohne Position.
select
  z.betrieb_id,
  z.projekt_id,
  'zeiteintrag'::text                       as gegenstand,
  z.id                                      as gegenstand_id,
  'ohne_position'::text                     as regel,
  coalesce(nullif(btrim(z.taetigkeit), ''), 'Arbeitszeit ohne Zuordnung') as bezeichnung,
  round((extract(epoch from (z.ende - z.beginn)) / 3600.0
         - z.pause_minuten / 60.0)::numeric, 2)                           as menge,
  'Std'::text                               as einheit,
  round(((extract(epoch from (z.ende - z.beginn)) / 3600.0
          - z.pause_minuten / 60.0) * ma.stundensatz)::numeric, 2)        as betrag,
  z.beginn                                  as erfasst_am,
  z.nachweis_id,
  false                                     as betrag_vorlaeufig
from zeiteintrag z
join mitarbeiter ma on ma.betrieb_id = z.betrieb_id and ma.id = z.mitarbeiter_id
where z.position_id is null
  and z.ende is not null
  and z.projekt_id is not null
  and not exists (
    select 1 from klaerung k
     where k.betrieb_id = z.betrieb_id
       and k.gegenstand = 'zeiteintrag' and k.gegenstand_id = z.id
  )

union all

-- Regel 2: Materialentnahme ohne Position.
select
  m.betrieb_id,
  m.projekt_id,
  'materialentnahme'::text,
  m.id,
  'ohne_position'::text,
  coalesce(nullif(btrim(m.bezeichnung), ''), a.bezeichnung, 'Material ohne Zuordnung'),
  m.menge,
  m.einheit,
  round(m.menge * coalesce(nullif(m.ek_preis, 0), a.ek_preis, 0), 2),
  m.erfasst_am,
  m.nachweis_id,
  false
from materialentnahme m
left join artikel a on a.betrieb_id = m.betrieb_id and a.id = m.artikel_id
where m.position_id is null
  and not exists (
    select 1 from klaerung k
     where k.betrieb_id = m.betrieb_id
       and k.gegenstand = 'materialentnahme' and k.gegenstand_id = m.id
  )

union all

-- Regel 3: Ist ueber 110 % des Solls, § 2 Abs. 3 Nr. 2 VOB/B.
--
-- Der Betrag ist ausdruecklich vorlaeufig. Ab 110 % ist laut BGH nicht mehr
-- die urspruengliche Preisermittlung massgeblich, sondern die tatsaechlich
-- erforderlichen Kosten der Mehrmenge. Der alte Einheitspreis ist hier also
-- eine Groessenordnung, kein Anspruch - und die Oberflaeche sagt das dazu.
select
  l.betrieb_id,
  l.projekt_id,
  'position_mehrmenge'::text,
  l.position_id,
  'mehrmenge'::text,
  l.bezeichnung,
  round(l.ist_menge - l.soll_menge, 2),
  l.einheit,
  round((l.ist_menge - l.soll_menge) * l.einzelpreis, 2),
  null::timestamptz,
  null::uuid,
  true
from leistungsstand l
where l.gruppe is not null
  and l.soll_menge > 0
  and l.ist_menge > l.soll_menge * 1.10
  and not exists (
    select 1 from klaerung k
     where k.betrieb_id = l.betrieb_id
       and k.gegenstand = 'position_mehrmenge' and k.gegenstand_id = l.position_id
  );

-- ------------------------------------------------------------------ RLS ----
-- Dieselben vier Muster wie in 0006.
alter table materialentnahme enable row level security;
create policy materialentnahme_mandant on materialentnahme
  for all to authenticated
  using      (betrieb_id = any (array(select meine_betriebe())))
  with check (betrieb_id = any (array(select meine_betriebe())));

-- Klaerung ist eine Bueroentscheidung: lesen darf der ganze Betrieb, anlegen
-- und zuruecknehmen nur, wer schreibend zugehoerig ist.
alter table klaerung enable row level security;
create policy klaerung_lesen on klaerung
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));
create policy klaerung_anlegen on klaerung
  for insert to authenticated
  with check (betrieb_id = any (array(select meine_betriebe_schreibend())));
create policy klaerung_zuruecknehmen on klaerung
  for delete to authenticated
  using (betrieb_id = any (array(select meine_betriebe_schreibend())));

-- ---------------------------------------------------------------- Journal --
-- Materialentnahme ist buchungsrelevant, die Klaerung ist die Begruendung
-- dazu. Beides gehoert ins Journal.
create trigger trg_journal_materialentnahme
  after insert or update or delete on materialentnahme
  for each row execute function journal_schreiben();
create trigger trg_journal_klaerung
  after insert or update or delete on klaerung
  for each row execute function journal_schreiben();

-- ------------------------------------------------------------- Rechte -----
-- Seit 0017 erbt nichts mehr. Jede neue Tabelle, jede neue Sicht und jede
-- neue Funktion braucht ihre Freigabe ausgeschrieben - genau das ist der
-- Sinn der Uebung.
grant select, insert, update, delete on materialentnahme to authenticated;
grant select, insert, delete         on klaerung         to authenticated;
grant select on leistungsstand, ungeklaerte_leistung to authenticated;

revoke all on function einheit_gruppe(text) from public;
grant execute on function einheit_gruppe(text) to authenticated;
