-- Indexdeckung der zusammengesetzten Fremdschluessel.
--
-- 0008 hat alle Fremdschluessel auf (betrieb_id, id) umgestellt. Das hat die
-- Mandantengrenze referenziell dichtgemacht - und nebenbei jeden vorhandenen
-- Index auf der Kindspalte entwertet. Ein Index auf (kunde_id) deckt den
-- Schluessel (betrieb_id, kunde_id) nicht: Postgres braucht die Spalten in der
-- Reihenfolge des Schluessels, von links.
--
-- Nach 0008 war deshalb kein einziger dieser Schluessel gedeckt. Zu spueren ist
-- das an zwei Stellen:
--
--   * Jedes DELETE oder UPDATE auf einer Elternzeile prueft die Kindtabellen.
--     Ohne Index ist das ein Seq Scan je Kindtabelle und je Zeile.
--   * betrieb_loeschen() loescht eine Betriebszeile und laesst die Kaskade durch
--     saemtliche Fachtabellen laufen. Genau der Pfad, der jede Pruefung
--     ungedeckt ausfuehrt - und der einzige Weg, einen Mandanten zu entfernen.
--
-- Der Supabase-Lint meldet 20 ungedeckte Schluessel, tatsaechlich sind es 23.
-- Der Lint laesst Teilindizes als Deckung gelten; ein Teilindex deckt aber nur
-- die Zeilen seines Praedikats, und die Fremdschluesselpruefung fragt nach
-- beliebigen. Betroffen sind einsatz_mitarbeiter_fk (nur vom GiST-Teilindex der
-- Ueberschneidungspruefung beruehrt), sicherheit_projekt_fk und
-- zeiteintrag_position_fk.
--
-- supabase/tests/03_fremdreferenzen.sql prueft die Deckung ab jetzt mit.

-- ------------------------------------------------------------------- 1 -------
-- Deckung herstellen. Wo ohnehin eine Sortierung gebraucht wird, deckt der
-- Index beides ab: die ersten beiden Spalten sind der Fremdschluessel, die
-- dritte die Ordnung.
create index if not exists ansprechpartner_kunde_fk_idx
  on ansprechpartner (betrieb_id, kunde_id);

create index if not exists artikel_lieferant_fk_idx
  on artikel (betrieb_id, lieferant_id);

create index if not exists beleg_erstellt_von_fk_idx
  on beleg (erstellt_von);
create index if not exists beleg_kunde_fk_idx
  on beleg (betrieb_id, kunde_id);
create index if not exists beleg_projekt_fk_idx
  on beleg (betrieb_id, projekt_id);
create index if not exists beleg_storniert_durch_fk_idx
  on beleg (betrieb_id, storniert_durch);
create index if not exists beleg_vorgaenger_fk_idx
  on beleg (betrieb_id, vorgaenger_id);

create index if not exists anrechnung_abschlagsrechnung_fk_idx
  on beleg_anrechnung (betrieb_id, abschlagsrechnung_id);
create index if not exists anrechnung_zahlung_fk_idx
  on beleg_anrechnung (betrieb_id, zahlung_id);

create index if not exists beleg_position_artikel_fk_idx
  on beleg_position (betrieb_id, artikel_id);

create index if not exists dokumentation_erfasst_von_fk_idx
  on dokumentation (betrieb_id, erfasst_von);
-- Deckt den Schluessel und die Ansicht "Doku eines Projekts, neueste zuerst".
create index if not exists dokumentation_projekt_fk_idx
  on dokumentation (betrieb_id, projekt_id, erfasst_am desc);

create index if not exists einbehalt_sicherheit_fk_idx
  on einbehalt_position (betrieb_id, sicherheit_id);

create index if not exists einsatz_mitarbeiter_fk_idx
  on einsatz (betrieb_id, mitarbeiter_id);
create index if not exists einsatz_projekt_fk_idx
  on einsatz (betrieb_id, projekt_id);
create index if not exists einsatz_subunternehmer_fk_idx
  on einsatz (betrieb_id, subunternehmer_id);

create index if not exists mitarbeiter_benutzer_fk_idx
  on mitarbeiter (benutzer_id);

create index if not exists projekt_kunde_fk_idx
  on projekt (betrieb_id, kunde_id);

create index if not exists sicherheit_projekt_fk_idx
  on sicherheit (betrieb_id, projekt_id);

create index if not exists zahlung_beleg_fk_idx
  on zahlung (betrieb_id, beleg_id);

-- Deckt den Schluessel und "letzte Zeiten einer Mitarbeiterin".
create index if not exists zeiteintrag_mitarbeiter_fk_idx
  on zeiteintrag (betrieb_id, mitarbeiter_id, beginn desc);
-- Deckt den Schluessel und "noch nicht abgerechnet" (position_id is null).
-- Btree indiziert NULL-Werte mit, der Teilindex von vorher wird dadurch
-- entbehrlich.
create index if not exists zeiteintrag_position_fk_idx
  on zeiteintrag (betrieb_id, position_id);
create index if not exists zeiteintrag_projekt_fk_idx
  on zeiteintrag (betrieb_id, projekt_id);

-- ------------------------------------------------------------------- 2 -------
-- Aufraeumen. Jeder Index kostet bei jedem INSERT und UPDATE Arbeit, deshalb
-- bleiben nur die, die etwas leisten.
--
-- Zwei deckungsgleiche Indizes auf journal - einer aus 0005, einer aus der
-- Haertung in 0007. Beide (betrieb_id, erfasst_am desc).
drop index if exists journal_betrieb_id_erfasst_am_idx;

-- Die einspaltigen Indizes auf betrieb_id sind allesamt echte Praefixe eines
-- vorhandenen mehrspaltigen Index - entweder der Eindeutigkeit (betrieb_id, id)
-- aus 0008 oder einer der Sortierungen oben. Ein Praefix leistet nichts, was der
-- laengere Index nicht auch leistet.
drop index if exists ansprechpartner_betrieb_id_idx;
drop index if exists artikel_betrieb_id_idx;
drop index if exists beleg_betrieb_id_idx;
drop index if exists beleg_anrechnung_betrieb_id_idx;
drop index if exists beleg_position_betrieb_id_idx;
drop index if exists dokumentation_betrieb_id_idx;
drop index if exists einbehalt_position_betrieb_id_idx;
drop index if exists einsatz_betrieb_id_idx;
drop index if exists kunde_betrieb_id_idx;
drop index if exists lieferant_betrieb_id_idx;
drop index if exists mitarbeiter_betrieb_id_idx;
drop index if exists projekt_betrieb_id_idx;
drop index if exists sicherheit_betrieb_id_idx;
drop index if exists zahlung_betrieb_id_idx;
drop index if exists zeiteintrag_betrieb_id_idx;

-- Ersetzt durch die mandantenfuehrenden Varianten weiter oben.
drop index if exists dokumentation_projekt_id_erfasst_am_idx;
drop index if exists zeiteintrag_mitarbeiter_id_beginn_idx;
drop index if exists zeiteintrag_betrieb_id_position_id_idx;

-- Die einspaltigen Indizes auf der Kindspalte. Jede Abfrage auf diese Tabellen
-- traegt durch RLS eine Bedingung auf betrieb_id - die Policy setzt sie ein,
-- auch wenn die Anwendung sie nicht schreibt. Damit fuehrt jeder Zugriff ueber
-- den mandantenfuehrenden Index, und der einspaltige liegt nur noch im Weg.
drop index if exists ansprechpartner_kunde_id_idx;
drop index if exists beleg_kunde_id_idx;
drop index if exists beleg_projekt_id_idx;
drop index if exists beleg_position_beleg_id_idx;
drop index if exists beleg_anrechnung_schlussrechnung_id_idx;
drop index if exists einbehalt_position_sicherheit_id_idx;
drop index if exists einsatz_projekt_id_idx;
drop index if exists projekt_kunde_id_idx;
drop index if exists sicherheit_projekt_id_idx;
drop index if exists zahlung_beleg_id_idx;
drop index if exists zeiteintrag_projekt_id_idx;
