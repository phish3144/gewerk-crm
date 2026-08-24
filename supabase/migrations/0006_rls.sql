-- Mandantentrennung. Vier Muster sind Pflicht, nicht Geschmackssache — die
-- Zahlen stammen aus Supabases eigenen Messungen (docs/recherche.md §6):
--
--   1. Auth-Funktion in Unterabfrage wickeln .......... 179 ms -> 9 ms
--   2. Join-Richtung: Zeilenspalte gegen feste Menge .. 9.000 ms -> 20 ms
--   3. Rolle in der TO-Klausel benennen ............... 170 ms -> < 0,1 ms
--   4. Index auf betrieb_id PLUS array(select ...) .... Timeout > 3 min -> ~2 ms
--
-- Muster 1 und 2 stecken in meine_betriebe() (0001), Muster 4 im array(...)
-- unten zusammen mit den Indizes aus 0001 bis 0004.

-- Der Betrieb selbst: hier ist die Mandantenspalte die Primärschlüsselspalte.
alter table betrieb enable row level security;
create policy betrieb_eigene on betrieb
  for all to authenticated
  using      (id = any (array(select meine_betriebe())))
  with check (id = any (array(select meine_betriebe())));

-- Benutzer sieht sich selbst und die Kollegen der eigenen Betriebe.
alter table benutzer enable row level security;
create policy benutzer_sichtbar on benutzer
  for select to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from benutzer_betrieb bb
       where bb.benutzer_id = benutzer.id
         and bb.betrieb_id = any (array(select meine_betriebe()))
    )
  );

-- Zugehörigkeiten sind lesbar, aber nicht durch die Anwendungsrolle änderbar:
-- wer sich selbst einem fremden Betrieb zuordnen könnte, hebelt die gesamte
-- Trennung aus. Einladungen laufen über eine gesonderte Funktion.
alter table benutzer_betrieb enable row level security;
create policy benutzer_betrieb_lesen on benutzer_betrieb
  for select to authenticated
  using (
    benutzer_id = (select auth.uid())
    or betrieb_id = any (array(select meine_betriebe()))
  );

-- Alle mandantengebundenen Tabellen nach demselben Muster.
do $$
declare
  t text;
begin
  foreach t in array array[
    'kunde', 'ansprechpartner', 'mitarbeiter', 'lieferant', 'artikel', 'projekt',
    'beleg', 'beleg_position', 'dokumentation', 'zeiteintrag', 'einsatz',
    'nummernkreis'
  ]
  loop
    execute format('alter table %I enable row level security', t);
    execute format($f$
      create policy %I on %I
        for all to authenticated
        using      (betrieb_id = any (array(select meine_betriebe())))
        with check (betrieb_id = any (array(select meine_betriebe())))
    $f$, t || '_mandant', t);
  end loop;
end $$;

-- Das Journal ist für den eigenen Betrieb lesbar und für niemanden schreibbar.
-- Geschrieben wird ausschließlich durch den security-definer-Trigger.
alter table journal enable row level security;
create policy journal_lesen on journal
  for select to authenticated
  using (betrieb_id = any (array(select meine_betriebe())));

-- Rechte. anon bekommt nichts: es gibt keinen öffentlichen Teil.
grant select, insert, update, delete on
  betrieb, kunde, ansprechpartner, mitarbeiter, lieferant, artikel, projekt,
  beleg, beleg_position, dokumentation, zeiteintrag, einsatz, nummernkreis
  to authenticated;
grant select on benutzer, benutzer_betrieb, journal to authenticated;
grant execute on function beleg_festschreiben(uuid) to authenticated;
grant execute on function beleg_summen_neu(uuid)    to authenticated;
-- naechste_nummer wird von beleg_festschreiben aufgerufen. Beide laufen als
-- security invoker, damit RLS greift: der Zugriff auf nummernkreis ist bereits
-- durch die Mandanten-Policy gedeckt, ein fremder betrieb_id laeuft dort in die
-- with-check-Verletzung. Deshalb reicht das Ausfuehrungsrecht - eine
-- security-definer-Funktion muesste die Zugehoerigkeit selbst pruefen und waere
-- die schwaechere Loesung.
revoke execute on function naechste_nummer(uuid, beleg_art) from public;
grant  execute on function naechste_nummer(uuid, beleg_art) to authenticated;
