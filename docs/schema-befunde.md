# Schema-Befunde

Ergebnis einer adversarialen Pruefung des Datenbankschemas: 43 Rohfunde,
**38 nach dreifacher Gegenpruefung bestaetigt**, 5 verworfen. Die bestaetigten
Funde wurden nicht behauptet, sondern in psql reproduziert.

Der schwerste Fund, mit Beweis vorher/nachher:

```
VORHER  (Migrationen 0001-0007)
  Anna aus Betrieb A fuegt eine Position in Brunos festgeschriebene
  Schlussrechnung ein  ->  ANGRIFF ERFOLGREICH, 2 Positionen

NACHHER (mit 0008 Mandantenbindung + 0010 GoBD-Sperre)
  derselbe Aufruf                                ->  abgewehrt, 1 Position
```

Ursache: kein Fremdschluessel trug eine Mandantenkomponente, und Postgres
fuehrt Fremdschluessel-Pruefungen als Tabelleneigentuemer **ohne RLS** aus. Eine
Policy kann das prinzipiell nicht heilen. Seit 0008 verweist jeder
Fremdschluessel auf das Paar `(betrieb_id, id)` - ein mandantenuebergreifender
Verweis ist damit nicht mehr verboten, sondern nicht mehr formulierbar.

## Stand

| | behoben | offen |
|---|---|---|
| kritisch | 8 | 2 |
| hoch | 8 | 8 |
| mittel | 3 | 5 |
| niedrig | 1 | 3 |
| **gesamt** | **20** | **18** |

## Behoben

- **kritisch** — Policies pruefen nur betrieb_id, nie den Mandanten der Elternzeile — fremde Belege lassen sich mit Positionen bestuecken
- **kritisch** — Fremdschlüssel prüfen nur id statt (betrieb_id, id) — RLS greift bei referentieller Integrität prinzipbedingt nicht
- **kritisch** — ON DELETE CASCADE über die Mandantengrenze vernichtet Daten im fremden Betrieb, ohne Journaleintrag
- **kritisch** — naechste_nummer ist fuer authenticated direkt aufrufbar und verbrennt Nummern ohne Beleg
- **kritisch** — nummernkreis ist fuer authenticated voll schreibbar; DELETE+INSERT umgeht den Rueckwaerts-Trigger komplett
- **kritisch** — position_unveraenderlich prueft nur den Ziel-Beleg: Positionen lassen sich aus einer festgeschriebenen Rechnung herausziehen
- **kritisch** — Rechnungsnummern sind nur je Belegart eindeutig – vier Rechnungen tragen dieselbe Nummer
- **kritisch** — Festgeschriebene Belege lassen sich per Nebenlaeufigkeit noch aendern (GoBD-Unveraenderbarkeit ausgehebelt)
- **hoch** — position_unveraenderlich() deutet 'durch RLS unsichtbar' als 'Beleg existiert nicht' und laesst die GoBD-Sperre ins Leere laufen
- **hoch** — Fremdschluessel duerfen ueber Mandantengrenzen zeigen: Betrieb A friert Stammdaten von Betrieb B dauerhaft ein
- **hoch** — Ausschluss-Constraint auf einsatz wirkt mandantenuebergreifend: Orakel auf fremde Einsatzzeiten und dauerhafte Blockade fremder Monteure
- **hoch** — position_unveraenderlich() liest den Belegstatus RLS-gefiltert — bei fremdem Beleg fällt die GoBD-Sperre aus
- **hoch** — ON DELETE RESTRICT über die Mandantengrenze sperrt Löschungen im fremden Betrieb dauerhaft und unauflösbar
- **hoch** — Ausschluss-Constraint einsatz_mitarbeiter_ohne_ueberschneidung ist nicht auf betrieb_id eingeschränkt
- **hoch** — Beleg speichert keine Stammdaten-Kopie; Kunde und Betrieb sind nachtraeglich aenderbar und ungejournalt
- **hoch** — Stornoverweis ist ungeprueft, frei umsetzbar und jederzeit wieder loeschbar
- **mittel** — unique (beleg_id, position_nr) ohne betrieb_id ist ein Existenzorakel auf fremde Belege
- **mittel** — Nummernkreis zieht das Jahr aus current_date statt aus beleg.datum – Belege vom Jahresende landen im Kreis des Folgejahres
- **mittel** — Lueckenlosigkeit des Nummernkreises ist nicht durchgesetzt: die Anwendungsrolle kann Nummern verbrennen und den Zaehler vorspulen
- **niedrig** — journal.id ist eine globale Identity-Sequenz und macht das Schreibaufkommen aller Mandanten messbar

## Offen

- **kritisch** — Mandantentest deckt nur kunde, projekt und betrieb ab — 11 von 12 Policy-Tabellen sind ungeprueft
- **kritisch** — Die Journal-Policy wird von keinem Test beruehrt — 'using (true)' faellt nicht auf
- **hoch** — Zahlungsziel und Skonto hängen am Kunden statt am Beleg – festgeschriebene Rechnungen ändern rückwirkend ihre Konditionen
- **hoch** — Einheitspreise als numeric(14,2): Materialpreise mit mehr als zwei Nachkommastellen werden beim Speichern verfälscht
- **hoch** — Erste Nummer eines Jahres bzw. einer Belegart: naechste_nummer bricht bei Gleichzeitigkeit mit duplicate key ab
- **hoch** — Die Rolle anon wird nie angenommen — der Block 'Ohne Anmeldung' laeuft als authenticated
- **hoch** — Unveraenderbarkeit wird nur an netto und nummer geprueft — Kunde, Datum, Leistungsdatum und Betreff bleiben ungetestet
- **hoch** — Journal-Test prueft nur Neuanlagen — fehlende Journalisierung von update und delete faellt nicht auf
- **hoch** — Nummernkreis-Test prueft nur UPDATE — DELETE ist der Anwendungsrolle erlaubt und setzt den Zaehler zurueck
- **hoch** — Die Policy benutzer_sichtbar wird von keinem Test geprueft
- **mittel** — Erste Festschreibung eines (betrieb, art, jahr) ist nicht nebenlaeufigkeitsfest: duplicate key auf nummernkreis_pkey
- **mittel** — Summen-Trigger verliert Aktualisierungen: Kopfsummen weichen von den Positionen ab
- **mittel** — Summen-Trigger je Zeile: quadratische Laufzeit, Dauersperre auf der Beleg-Zeile und aufgeblaehtes Journal
- **mittel** — ON DELETE CASCADE von betrieb ist unerreichbar, sobald ein Beleg festgeschrieben ist
- **mittel** — Kein Test fuer einen Nutzer in zwei Betrieben — meine_betriebe() darf still auf einen Betrieb schrumpfen
- **niedrig** — betriebsrolle wird in keiner Policy ausgewertet — jedes Konto im Betrieb hat Vollzugriff
- **niedrig** — Belegdatum ist beliebig rueckdatierbar und wird erst nach der Festschreibung eingefroren
- **niedrig** — journal.betrieb_id ohne Fremdschluessel: nach dem Loeschen eines Betriebs bleiben unloeschbare, fuer niemanden lesbare Waisenzeilen

## Verworfen

Fuenf Funde hielten der Gegenpruefung nicht stand, darunter vier zum
Rechnungsmodell (Abschlagsrechnungen, Einbehalte, Reverse Charge, Nachtraege).
Die Pruefer haben zu Recht erkannt, dass diese Punkte in
[offene-fragen.md](offene-fragen.md) bereits als ungeklaert vermerkt sind und
deshalb kein Umsetzungsfehler vorliegt.

## Reproduzieren

```
./supabase/tests/run.sh
```

Startet einen lokalen Postgres, spielt alle Migrationen ein und laesst die
Testdateien laufen. Der Shim unter `supabase/local/` bildet nach, was Supabase
bereits mitbringt (`auth.uid()`, die Rollen) und wird nie auf ein
Supabase-Projekt angewendet.
