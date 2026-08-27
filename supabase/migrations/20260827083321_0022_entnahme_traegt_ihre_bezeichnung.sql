-- Die Materialentnahme traegt ihre Bezeichnung selbst.
--
-- Befund aus dem Nachlauf zu 0020, am lebenden Projekt reproduziert:
--
--   delete from artikel where nummer = '...';
--   ERROR: new row for relation "materialentnahme" violates check constraint
--          "material_benannt"
--
-- Der Weg dorthin: artikel_id steht auf ON DELETE SET NULL, und wenn die
-- Entnahme ihre Bezeichnung aus dem Stammsatz bezog, bleibt danach eine Zeile
-- ohne jede Benennung uebrig. Die Pruefregel faengt das ab - richtig, aber die
-- Folge ist, dass ein einmal gebuchter Artikel nie wieder loeschbar ist, und
-- die Meldung nennt wieder die falsche Tabelle.
--
-- Die Ursache liegt tiefer als die Meldung: 0020 kopiert bereits den
-- Einkaufspreis in die Entnahme, mit genau dieser Begruendung - der Stammpreis
-- aendert sich, der Wert der Entnahme nicht. Fuer die Bezeichnung gilt
-- dasselbe. Ein Artikel wird umbenannt oder ausgelistet; was am 12. Maerz von
-- der Baustelle verbraucht wurde, aendert sich dadurch nicht.

update materialentnahme m
   set bezeichnung = a.bezeichnung
  from artikel a
 where a.id = m.artikel_id
   and (m.bezeichnung is null or btrim(m.bezeichnung) = '');

-- Falls doch eine Zeile ohne beides existiert: sie waere nach 0020 gar nicht
-- entstanden, aber verlassen wird sich darauf nicht.
update materialentnahme
   set bezeichnung = 'Material ohne Bezeichnung'
 where bezeichnung is null or btrim(bezeichnung) = '';

alter table materialentnahme alter column bezeichnung set not null;

-- material_benannt ist damit gegenstandslos: bezeichnung ist immer da. An ihre
-- Stelle tritt die Regel, die tatsaechlich noch etwas zusichert.
alter table materialentnahme drop constraint material_benannt;
alter table materialentnahme add  constraint material_benannt
  check (btrim(bezeichnung) <> '');

-- Die Sicht griff bisher auf den Artikelstamm zurueck, wenn die Entnahme keine
-- eigene Bezeichnung hatte. Das ist nicht mehr noetig - und waere jetzt sogar
-- falsch: ein umbenannter Artikel wuerde die Meldung von vor drei Monaten
-- rueckwirkend anders beschriften.
create or replace view ungeklaerte_leistung with (security_invoker = true) as
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

select
  m.betrieb_id,
  m.projekt_id,
  'materialentnahme'::text,
  m.id,
  'ohne_position'::text,
  m.bezeichnung,
  m.menge,
  m.einheit,
  round(m.menge * m.ek_preis, 2),
  m.erfasst_am,
  m.nachweis_id,
  false
from materialentnahme m
where m.position_id is null
  and not exists (
    select 1 from klaerung k
     where k.betrieb_id = m.betrieb_id
       and k.gegenstand = 'materialentnahme' and k.gegenstand_id = m.id
  )

union all

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

grant select on ungeklaerte_leistung to authenticated;
