-- Vier bestaetigte Befunde: Preisgenauigkeit, Faelligkeit, Belegdatum und der
-- Summen-Trigger.

-- ------------------------------------------------------------------------ 1 --
-- Menge war vierstellig, der Einzelpreis nur zweistellig. In Elektro, SHK und
-- Trockenbau sind Meter- und Stueckpreise unterhalb eines Cents die Regel, und
-- IDS-Connect- und DATANORM-Preislisten liefern vier Nachkommastellen.
--
--   NYM-J 3x1,5 zu 0,1870 EUR/m wurde beim Speichern zu 0,19 EUR/m.
--   Auf 5.000 m sind das 950,00 statt 935,00 EUR - 1,6 % zu viel, und zwar
--   auf jeder Position, die je importiert wurde.
--
-- Die Rundung auf zwei Stellen gehoert an das Ende der Rechnung, nicht an den
-- Anfang: gesamt rundet weiterhin kaufmaennisch je Position.
alter table beleg_position drop column gesamt;

alter table beleg_position
  alter column einzelpreis          type numeric(14,4),
  alter column lohn_anteil          type numeric(14,4),
  alter column material_anteil      type numeric(14,4),
  alter column fremdleistung_anteil type numeric(14,4);

alter table artikel
  alter column ek_preis type numeric(14,4),
  alter column vk_preis type numeric(14,4);

alter table beleg_position
  add column gesamt numeric(14,2)
    generated always as (round(menge * einzelpreis * (1 - rabatt_prozent / 100), 2)) stored;

-- ------------------------------------------------------------------------ 2 --
-- Der Beleg trug seit 0010 zwar Zahlungsziel und Skonto als Kopie, aber kein
-- Faelligkeitsdatum. Fuer Mahnwesen und Verzug ist genau das die maßgebliche
-- Groesse, und sie darf sich nach der Festschreibung nicht mehr bewegen.
alter table beleg add column faelligkeit_am date;

-- ------------------------------------------------------------------------ 3 --
-- Das Belegdatum war beliebig rueckdatierbar und wurde erst durch die
-- Festschreibung eingefroren - danach galt genau das falsche Datum als
-- unveraenderlich. Umsatz liess sich so in eine abgeschlossene Periode
-- zurueckdatieren.
alter table beleg add constraint beleg_datum_nicht_nach_festschreibung check (
  festgeschrieben_am is null or datum <= (festgeschrieben_am at time zone 'Europe/Berlin')::date
);

-- ------------------------------------------------------------------------ 4 --
-- Der Summen-Trigger lief je Zeile: bei N Positionen N vollstaendige
-- Aggregationen und N UPDATEs auf derselben Beleg-Zeile, also O(N^2), dazu N
-- Journalzeilen. Ein GAEB-Import mit 4.000 Positionen sperrte den Beleg
-- sekundenlang.
--
-- Zusaetzlich las beleg_summen_neu ohne vorherige Sperre: zwei gleichzeitige
-- Positionsaenderungen berechneten beide ihre Summe, bevor die andere sichtbar
-- war, und die zweite ueberschrieb das Ergebnis der ersten mit einem veralteten
-- Wert. Der Kopf wich dann dauerhaft von den Positionen ab, ohne dass die
-- CHECK-Bedingung auffiel - netto, steuer und brutto blieben untereinander
-- stimmig, nur eben falsch.
--
-- Jetzt einmal je Anweisung, und die Sperre steht vor dem Lesen.
drop trigger trg_beleg_position_summen on beleg_position;

create or replace function beleg_summen_stmt()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_belege uuid[];
  v_beleg  uuid;
begin
  if tg_op = 'INSERT' then
    select array_agg(distinct beleg_id) into v_belege from betroffen_neu;
  elsif tg_op = 'DELETE' then
    select array_agg(distinct beleg_id) into v_belege from betroffen_alt;
  else
    select array_agg(distinct b) into v_belege
      from (select beleg_id as b from betroffen_neu
            union
            select beleg_id from betroffen_alt) q;
  end if;

  foreach v_beleg in array coalesce(v_belege, '{}'::uuid[])
  loop
    -- Sperre VOR dem Aggregieren, sonst rechnet eine gleichzeitige Anweisung
    -- auf einem veralteten Stand und ueberschreibt das Ergebnis.
    perform 1 from beleg where id = v_beleg for update;
    perform beleg_summen_neu(v_beleg);
  end loop;
  return null;
end $$;

create trigger trg_beleg_position_summen_ins
  after insert on beleg_position
  referencing new table as betroffen_neu
  for each statement execute function beleg_summen_stmt();

create trigger trg_beleg_position_summen_upd
  after update on beleg_position
  referencing new table as betroffen_neu old table as betroffen_alt
  for each statement execute function beleg_summen_stmt();

create trigger trg_beleg_position_summen_del
  after delete on beleg_position
  referencing old table as betroffen_alt
  for each statement execute function beleg_summen_stmt();
