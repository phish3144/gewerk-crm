-- journal.id ist eine betriebsuebergreifende Identity-Sequenz. Ein Mandant
-- sieht durch die Policy zwar nur seine eigenen Zeilen, liest an den Luecken
-- zwischen deren IDs aber ab, wie viel die uebrigen Mandanten in der
-- Zwischenzeit geschrieben haben - ein Seitenkanal auf fremdes Geschaeftsvolumen.
--
-- Die Spalte wird deshalb nicht mehr an die Anwendungsrolle ausgeliefert.
-- Sortiert wird ueber erfasst_am; die Reihenfolge innerhalb einer Anweisung ist
-- fuer die Anzeige ohne Belang.
revoke select on journal from authenticated;
grant select (betrieb_id, tabelle, datensatz_id, aktion, vorher, nachher, benutzer_id, erfasst_am)
  on journal to authenticated;

create index if not exists journal_betrieb_zeit on journal (betrieb_id, erfasst_am desc);
