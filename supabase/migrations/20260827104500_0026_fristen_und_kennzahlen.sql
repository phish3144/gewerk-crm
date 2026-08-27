-- Uebersicht und Fristen.
--
-- Der Inhaber soll morgens sehen, was Geld kostet - und zwar in Euro und mit
-- Herkunft. Eine Kennzahl, die man nicht aufklappen kann, wird nicht geglaubt
-- und zu Recht ignoriert. Deshalb liefert jede Sicht hier Zeilen, keine
-- Summen; summiert wird erst in der Anzeige.

-- ------------------------------------------------------------- Abnahme -----
-- Die Abnahme ist das Ereignis, an dem die Gewaehrleistungsfrist haengt. Ohne
-- sie laesst sich keine Frist berechnen, und genau daran scheitert es in der
-- Praxis: das Datum steht auf einem Zettel im Ordner.
create type abnahme_art as enum ('foermlich', 'fiktiv', 'konkludent');

-- § 13 Abs. 4 VOB/B: vier Jahre fuer Bauwerke, zwei Jahre fuer Arbeiten an
-- Grundstuecken und fuer feuerberuehrte Teile von Feuerungsanlagen.
-- § 634a Abs. 1 Nr. 2 BGB: fuenf Jahre bei einem Bauwerk.
-- Welche gilt, entscheidet der Vertrag - deshalb ist es eine Angabe, keine
-- Ableitung.
create type gewaehrleistung_grundlage as enum ('vob_2j', 'vob_4j', 'bgb_2j', 'bgb_5j');

create table abnahme (
  id            uuid primary key default gen_random_uuid(),
  betrieb_id    uuid not null references betrieb(id) on delete cascade,
  projekt_id    uuid not null,
  art           abnahme_art not null default 'foermlich',
  abgenommen_am date not null,
  grundlage     gewaehrleistung_grundlage not null,
  -- Vorbehalte gehoeren ins Protokoll, nicht ins Gedaechtnis.
  vorbehalte    text,
  protokoll_id  uuid,
  erfasst_am    timestamptz not null default now(),
  erfasst_von   uuid not null references benutzer(id) on delete restrict,
  constraint abnahme_mandant_id unique (betrieb_id, id),
  -- Eine Baustelle wird einmal abgenommen. Eine zweite Abnahme waere eine
  -- Teilabnahme und braucht ein eigenes Modell.
  constraint abnahme_je_projekt unique (betrieb_id, projekt_id)
);
alter table abnahme add constraint abnahme_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id) on delete cascade;
alter table abnahme add constraint abnahme_protokoll_fk
  foreign key (betrieb_id, protokoll_id) references dokumentation (betrieb_id, id)
  on delete set null (protokoll_id);
-- Kein eigener Index auf (betrieb_id, projekt_id): abnahme_je_projekt ist
-- bereits genau dieser Schluessel und deckt den Fremdschluessel mit ab.
create index abnahme_protokoll_fk_idx on abnahme (betrieb_id, protokoll_id);
create index abnahme_erfasst_von_idx  on abnahme (erfasst_von);

-- Wie lange die Gewaehrleistung laeuft. Eigene Funktion, weil sie in der Sicht
-- und spaeter im Abnahmeprotokoll dieselbe Antwort geben muss.
create or replace function gewaehrleistung_bis(p_ab date, p_grundlage gewaehrleistung_grundlage)
  returns date
  language sql
  immutable
  set search_path = public, pg_temp
  as $$
    select (p_ab + case p_grundlage
      when 'vob_2j' then interval '2 years'
      when 'vob_4j' then interval '4 years'
      when 'bgb_2j' then interval '2 years'
      when 'bgb_5j' then interval '5 years'
    end)::date
  $$;

-- ------------------------------------------ Freistellungsbescheinigung ------
-- § 48b EStG. Wer eine Bauleistung von einem Subunternehmer bezieht und keine
-- gueltige Bescheinigung vorliegen hat, muss 15 % Bauabzugsteuer einbehalten -
-- und haftet dafuer, unabhaengig davon, ob er davon wusste.
--
-- Pruefen laesst sich eine Bescheinigung nur ueber das EIBE-Portal des BZSt,
-- ein Portal mit Registrierung und keine offene Schnittstelle. Die Anwendung
-- fragt deshalb NICHT automatisch ab; sie fuehrt Nummer und Ablauf und erinnert
-- rechtzeitig. Das ist der ehrliche Funktionsumfang, und er steht hier, damit
-- niemand spaeter eine automatische Pruefung vermutet, die es nicht gibt.
create table freistellungsbescheinigung (
  id               uuid primary key default gen_random_uuid(),
  betrieb_id       uuid not null references betrieb(id) on delete cascade,
  lieferant_id     uuid not null,
  sicherheitsnummer text not null,
  finanzamt        text,
  gueltig_von      date,
  gueltig_bis      date not null,
  -- Wann hat zuletzt ein Mensch im EIBE-Portal nachgesehen?
  geprueft_am      date,
  bemerkung        text,
  erfasst_am       timestamptz not null default now(),
  constraint fsb_zeitraum check (gueltig_von is null or gueltig_bis >= gueltig_von),
  constraint fsb_nummer_nicht_leer check (btrim(sicherheitsnummer) <> ''),
  constraint fsb_mandant_id unique (betrieb_id, id),
  unique (betrieb_id, lieferant_id, sicherheitsnummer)
);
alter table freistellungsbescheinigung add constraint fsb_lieferant_fk
  foreign key (betrieb_id, lieferant_id) references lieferant (betrieb_id, id) on delete cascade;
create index fsb_lieferant_fk_idx on freistellungsbescheinigung (betrieb_id, lieferant_id, gueltig_bis desc);

-- ------------------------------------------------------- Offene Posten -----
-- Was ist gestellt und noch nicht bezahlt? Zeilen, nicht Summen: die Zahl auf
-- der Uebersicht muss sich bis auf die einzelne Rechnung aufklappen lassen.
create or replace view offene_posten with (security_invoker = true) as
select
  b.betrieb_id,
  b.id            as beleg_id,
  b.projekt_id,
  b.kunde_id,
  b.art,
  b.nummer,
  b.datum,
  b.faelligkeit_am,
  coalesce(b.kunde_name, k.name) as kunde,
  b.brutto,
  coalesce(a.angerechnet, 0)     as angerechnet,
  coalesce(z.gezahlt, 0)         as gezahlt,
  round(b.brutto - coalesce(a.angerechnet, 0) - coalesce(z.gezahlt, 0), 2) as offen,
  -- Negativ heisst ueberfaellig. Die Anzeige braucht kein zweites Feld dafuer.
  (b.faelligkeit_am - current_date) as tage_bis_faellig
from beleg b
left join kunde k on k.betrieb_id = b.betrieb_id and k.id = b.kunde_id
left join lateral (
  select sum(x.angerechnet_brutto) as angerechnet
    from beleg_anrechnung x where x.schlussrechnung_id = b.id
) a on true
left join lateral (
  select sum(x.betrag_brutto + x.skonto_brutto) as gezahlt
    from zahlung x where x.beleg_id = b.id
) z on true
where b.art in ('abschlagsrechnung', 'teilrechnung', 'schlussrechnung')
  and b.status not in ('entwurf', 'storniert')
  and round(b.brutto - coalesce(a.angerechnet, 0) - coalesce(z.gezahlt, 0), 2) > 0;

-- ----------------------------------------------------------- Fristen -------
-- Alle Fristen, deren Versaeumnis unmittelbar Geld kostet, an einem Ort.
create or replace view fristen with (security_invoker = true) as

-- Gewaehrleistung. Laeuft sie ab, verjaehren die Ansprueche des Auftraggebers -
-- fuer den Betrieb ist das der Tag, an dem eine Ruecklage frei wird.
select
  a.betrieb_id,
  'gewaehrleistung'::text as art,
  a.projekt_id,
  a.id                    as gegenstand_id,
  p.bezeichnung           as bezeichnung,
  gewaehrleistung_bis(a.abgenommen_am, a.grundlage) as faellig_am,
  (gewaehrleistung_bis(a.abgenommen_am, a.grundlage) - current_date) as tage,
  null::numeric           as betrag,
  ('Abnahme am ' || to_char(a.abgenommen_am, 'DD.MM.YYYY') || ', ' ||
   case a.grundlage
     when 'vob_2j' then '2 Jahre (§ 13 Abs. 4 VOB/B)'
     when 'vob_4j' then '4 Jahre (§ 13 Abs. 4 VOB/B)'
     when 'bgb_2j' then '2 Jahre (§ 634a BGB)'
     when 'bgb_5j' then '5 Jahre (§ 634a Abs. 1 Nr. 2 BGB)'
   end)::text             as herkunft
from abnahme a
join projekt p on p.betrieb_id = a.betrieb_id and p.id = a.projekt_id

union all

-- Freistellungsbescheinigung. Laeuft sie ab, greift der Steuerabzug von 15 %
-- nach § 48 EStG, und der Auftraggeber haftet dafuer.
select
  f.betrieb_id,
  'freistellungsbescheinigung'::text,
  null::uuid,
  f.id,
  l.name,
  f.gueltig_bis,
  (f.gueltig_bis - current_date),
  null::numeric,
  ('Sicherheitsnummer ' || f.sicherheitsnummer ||
   coalesce(', zuletzt geprueft am ' || to_char(f.geprueft_am, 'DD.MM.YYYY'), ', noch nicht geprueft'))::text
from freistellungsbescheinigung f
join lieferant l on l.betrieb_id = f.betrieb_id and l.id = f.lieferant_id

union all

-- Sicherheitseinbehalt. Solange er nicht freigegeben ist, liegt das Geld beim
-- Auftraggeber (§ 17 VOB/B).
select
  s.betrieb_id,
  'sicherheitseinbehalt'::text,
  s.projekt_id,
  s.id,
  p.bezeichnung,
  coalesce(s.freigabe_vereinbart, s.freigabe_soll),
  (coalesce(s.freigabe_vereinbart, s.freigabe_soll) - current_date),
  s.einbehalten_ist,
  (case s.zweck
     when 'vertragserfuellung'  then 'Vertragserfuellungssicherheit'
     when 'maengelansprueche'   then 'Sicherheit fuer Maengelansprueche'
   end || ', einbehalten')::text
from sicherheit s
join projekt p on p.betrieb_id = s.betrieb_id and p.id = s.projekt_id
where s.freigegeben_am is null
  and coalesce(s.freigabe_vereinbart, s.freigabe_soll) is not null

union all

-- Skontofrist. Sie laeuft dem Zahlungsziel voraus; wer sie verstreichen laesst,
-- verschenkt den Abzug nicht, sondern bekommt das volle Geld - fuer den
-- Betrieb ist das der freundliche Fall. Wichtig ist er trotzdem: der Kunde
-- zieht Skonto oft auch nach Ablauf.
select
  o.betrieb_id,
  'skontofrist'::text,
  o.projekt_id,
  o.beleg_id,
  (o.nummer || ' · ' || o.kunde)::text,
  (o.datum + b.skonto_tage),
  (o.datum + b.skonto_tage - current_date),
  round(o.offen * b.skonto_prozent / 100, 2),
  (b.skonto_prozent || ' % Skonto bei Zahlung binnen ' || b.skonto_tage || ' Tagen')::text
from offene_posten o
join beleg b on b.betrieb_id = o.betrieb_id and b.id = o.beleg_id
where b.skonto_prozent is not null and b.skonto_prozent > 0
  and b.skonto_tage is not null and b.skonto_tage > 0

union all

-- Zahlungsziel. Danach ist der Kunde in Verzug.
select
  o.betrieb_id,
  'zahlungsziel'::text,
  o.projekt_id,
  o.beleg_id,
  (o.nummer || ' · ' || o.kunde)::text,
  o.faelligkeit_am,
  o.tage_bis_faellig,
  o.offen,
  ('Rechnung vom ' || to_char(o.datum, 'DD.MM.YYYY'))::text
from offene_posten o
where o.faelligkeit_am is not null;

-- ------------------------------------------------------ Nachkalkulation ----
-- Geplant gegen tatsaechlich, je Baustelle. Die geplante Seite steht in den
-- Kalkulationsanteilen der Auftragspositionen, die tatsaechliche in erfassten
-- Stunden und Materialentnahmen.
--
-- Bewusst ohne Deckungsbeitragsformel: was ein Betrieb als Gemeinkosten
-- ansetzt, ist eine betriebliche Entscheidung und keine, die eine Anwendung
-- unausgesprochen treffen darf.
create or replace view nachkalkulation with (security_invoker = true) as
select
  p.betrieb_id,
  p.id                                     as projekt_id,
  p.bezeichnung,
  coalesce(soll.auftragssumme, 0)          as auftragssumme,
  coalesce(soll.lohn_geplant, 0)           as lohn_geplant,
  coalesce(soll.material_geplant, 0)       as material_geplant,
  coalesce(soll.fremd_geplant, 0)          as fremd_geplant,
  coalesce(ist_zeit.stunden, 0)            as stunden_ist,
  coalesce(ist_zeit.lohnkosten, 0)         as lohn_ist,
  coalesce(ist_material.materialkosten, 0) as material_ist
from projekt p
left join lateral (
  select
    sum(bp.gesamt)                          as auftragssumme,
    sum(bp.lohn_anteil * bp.menge)          as lohn_geplant,
    sum(bp.material_anteil * bp.menge)      as material_geplant,
    sum(bp.fremdleistung_anteil * bp.menge) as fremd_geplant
  from beleg_position bp
  join beleg b on b.betrieb_id = bp.betrieb_id and b.id = bp.beleg_id
  where b.betrieb_id = p.betrieb_id and b.projekt_id = p.id
    and b.art in ('auftrag', 'nachtrag') and b.status <> 'entwurf'
    and bp.art not in ('text', 'titel')
) soll on true
left join lateral (
  select
    sum(extract(epoch from (z.ende - z.beginn)) / 3600.0 - z.pause_minuten / 60.0)::numeric(14,2) as stunden,
    sum((extract(epoch from (z.ende - z.beginn)) / 3600.0 - z.pause_minuten / 60.0)
        * m.stundensatz)::numeric(14,2) as lohnkosten
  from zeiteintrag z
  join mitarbeiter m on m.betrieb_id = z.betrieb_id and m.id = z.mitarbeiter_id
  where z.betrieb_id = p.betrieb_id and z.projekt_id = p.id and z.ende is not null
) ist_zeit on true
left join lateral (
  select sum(me.menge * me.ek_preis)::numeric(14,2) as materialkosten
  from materialentnahme me
  where me.betrieb_id = p.betrieb_id and me.projekt_id = p.id
) ist_material on true;

-- ------------------------------------------------------------------ RLS ----
alter table abnahme enable row level security;
create policy abnahme_lesen on abnahme
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));
create policy abnahme_schreiben on abnahme
  for all to authenticated
  using      (betrieb_id = any (array(select meine_betriebe_schreibend())))
  with check (betrieb_id = any (array(select meine_betriebe_schreibend())));

alter table freistellungsbescheinigung enable row level security;
create policy fsb_lesen on freistellungsbescheinigung
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));
create policy fsb_schreiben on freistellungsbescheinigung
  for all to authenticated
  using      (betrieb_id = any (array(select meine_betriebe_schreibend())))
  with check (betrieb_id = any (array(select meine_betriebe_schreibend())));

-- ---------------------------------------------------------------- Journal --
-- Die Abnahme ist das Ereignis, an dem Fristen haengen. Wann sie erfasst und
-- ob sie spaeter verschoben wurde, gehoert nachvollziehbar festgehalten.
create trigger trg_journal_abnahme
  after insert or update or delete on abnahme
  for each row execute function journal_schreiben();

-- ------------------------------------------------------------- Rechte -----
grant select, insert, update, delete on abnahme                   to authenticated;
grant select, insert, update, delete on freistellungsbescheinigung to authenticated;
grant select on offene_posten, fristen, nachkalkulation to authenticated;

revoke all on function gewaehrleistung_bis(date, gewaehrleistung_grundlage) from public, anon, authenticated;
grant execute on function gewaehrleistung_bis(date, gewaehrleistung_grundlage) to authenticated;
