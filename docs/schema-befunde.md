# Schema-Befunde

Adversariale Pruefung des Datenbankschemas: 43 Rohfunde, **38 nach dreifacher
Gegenpruefung bestaetigt**, 5 verworfen. Die bestaetigten Funde wurden nicht
behauptet, sondern in psql reproduziert.

**Stand: alle 38 umgesetzt.** Nachweis: `./supabase/tests/run.sh`

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

## Zwei Befunde, die erst der eigene Test zutage foerderte

**Das Journal war nur per REVOKE geschuetzt.** Als Tabelleneigentuemer ging
`update journal` widerstandslos durch - Rechte greifen gegen Eigentuemer und
Superuser nicht. Seit 0011 erzwingt ein Trigger das Anfuegen rollenunabhaengig.

**Der anon-Test war ein Scheinerfolg.** Er lief gruen, weil der lokalen Rolle
`anon` schlicht die Tabellenrechte fehlten - waehrend ein echtes
Supabase-Projekt sie per default privileges vergibt. Der Test prueft seit
`supabase/local/01_anon_wie_supabase.sql` gegen den Produktionszustand:
`anon` hat SELECT, INSERT, UPDATE und DELETE auf allen Tabellen und sieht
trotzdem null Zeilen. Was blockiert, ist die `TO authenticated`-Klausel der
Policies, nicht ein fehlendes Recht.

## Umsetzung je Befund

### kritisch (10)

- **Policies pruefen nur betrieb_id, nie den Mandanten der Elternzeile — fremde Belege lassen sich mit Positionen bestuecken**
  → 0008 zusammengesetzte Fremdschluessel + 0010 GoBD-Sperre; Test 03
- **Fremdschlüssel prüfen nur id statt (betrieb_id, id) — RLS greift bei referentieller Integrität prinzipbedingt nicht**
  → 0008 (betrieb_id, id) auf allen 17 Fremdschluesseln; Test 03
- **ON DELETE CASCADE über die Mandantengrenze vernichtet Daten im fremden Betrieb, ohne Journaleintrag**
  → 0008 - Kaskaden koennen die Mandantengrenze nicht mehr ueberschreiten; Test 03
- **naechste_nummer ist fuer authenticated direkt aufrufbar und verbrennt Nummern ohne Beleg**
  → 0009 revoke execute on naechste_nummer; Test 04
- **nummernkreis ist fuer authenticated voll schreibbar; DELETE+INSERT umgeht den Rueckwaerts-Trigger komplett**
  → 0009 revoke insert/update/delete on nummernkreis; Test 04
- **position_unveraenderlich prueft nur den Ziel-Beleg: Positionen lassen sich aus einer festgeschriebenen Rechnung herausziehen**
  → 0010 position_unveraenderlich prueft beide Belege; Test 04
- **Rechnungsnummern sind nur je Belegart eindeutig – vier Rechnungen tragen dieselbe Nummer**
  → 0009 Artkennung im Praefix, unique (betrieb_id, nummer); Test 04
- **Festgeschriebene Belege lassen sich per Nebenlaeufigkeit noch aendern (GoBD-Unveraenderbarkeit ausgehebelt)**
  → 0010 security definer + Sperre in beleg_festschreiben; Test 04
- **Mandantentest deckt nur kunde, projekt und betrieb ab — 11 von 12 Policy-Tabellen sind ungeprueft**
  → Test 05 datengetrieben ueber alle Tabellen mit betrieb_id (14 geprueft)
- **Die Journal-Policy wird von keinem Test beruehrt — 'using (true)' faellt nicht auf**
  → Test 05 Journal-Policy mit zwei Betrieben

### hoch (16)

- **position_unveraenderlich() deutet 'durch RLS unsichtbar' als 'Beleg existiert nicht' und laesst die GoBD-Sperre ins Leere laufen**
  → 0010 security definer
- **Fremdschluessel duerfen ueber Mandantengrenzen zeigen: Betrieb A friert Stammdaten von Betrieb B dauerhaft ein**
  → 0008
- **Ausschluss-Constraint auf einsatz wirkt mandantenuebergreifend: Orakel auf fremde Einsatzzeiten und dauerhafte Blockade fremder Monteure**
  → 0008 Ausschluss-Constraint auf betrieb_id geschnitten
- **position_unveraenderlich() liest den Belegstatus RLS-gefiltert — bei fremdem Beleg fällt die GoBD-Sperre aus**
  → 0010 security definer
- **ON DELETE RESTRICT über die Mandantengrenze sperrt Löschungen im fremden Betrieb dauerhaft und unauflösbar**
  → 0008
- **Ausschluss-Constraint einsatz_mitarbeiter_ohne_ueberschneidung ist nicht auf betrieb_id eingeschränkt**
  → 0008
- **Beleg speichert keine Stammdaten-Kopie; Kunde und Betrieb sind nachtraeglich aenderbar und ungejournalt**
  → 0010 Kundenkopie auf dem Beleg; Test 07
- **Stornoverweis ist ungeprueft, frei umsetzbar und jederzeit wieder loeschbar**
  → 0010 Stornoverweis einmal beschreibbar; Test 04
- **Zahlungsziel und Skonto hängen am Kunden statt am Beleg – festgeschriebene Rechnungen ändern rückwirkend ihre Konditionen**
  → 0010 Konditionen eingefroren + 0012/0014 faelligkeit_am; Test 07
- **Einheitspreise als numeric(14,2): Materialpreise mit mehr als zwei Nachkommastellen werden beim Speichern verfälscht**
  → 0012 numeric(14,4) fuer Preise und Anteile; Test 07
- **Erste Nummer eines Jahres bzw. einer Belegart: naechste_nummer bricht bei Gleichzeitigkeit mit duplicate key ab**
  → 0009 insert on conflict do nothing + update returning
- **Die Rolle anon wird nie angenommen — der Block 'Ohne Anmeldung' laeuft als authenticated**
  → Test 05 mit Rolle anon; Shim 01 stellt die Supabase-Rechte her
- **Unveraenderbarkeit wird nur an netto und nummer geprueft — Kunde, Datum, Leistungsdatum und Betreff bleiben ungetestet**
  → Test 07 datengetrieben ueber alle 24 geschuetzten Spalten
- **Journal-Test prueft nur Neuanlagen — fehlende Journalisierung von update und delete faellt nicht auf**
  → Test 07 insert, update und delete inkl. vorher-Abbild
- **Nummernkreis-Test prueft nur UPDATE — DELETE ist der Anwendungsrolle erlaubt und setzt den Zaehler zurueck**
  → 0009 revoke delete on nummernkreis; Test 04
- **Die Policy benutzer_sichtbar wird von keinem Test geprueft**
  → Test 05 benutzer_sichtbar mit Selbst, Kollege und Fremdem

### mittel (8)

- **unique (beleg_id, position_nr) ohne betrieb_id ist ein Existenzorakel auf fremde Belege**
  → 0008 unique (betrieb_id, beleg_id, position_nr)
- **Erste Festschreibung eines (betrieb, art, jahr) ist nicht nebenlaeufigkeitsfest: duplicate key auf nummernkreis_pkey**
  → 0009
- **Nummernkreis zieht das Jahr aus current_date statt aus beleg.datum – Belege vom Jahresende landen im Kreis des Folgejahres**
  → 0009 Jahr aus beleg.datum statt current_date
- **Summen-Trigger verliert Aktualisierungen: Kopfsummen weichen von den Positionen ab**
  → 0012 Sperre vor dem Aggregieren
- **Summen-Trigger je Zeile: quadratische Laufzeit, Dauersperre auf der Beleg-Zeile und aufgeblaehtes Journal**
  → 0012 Trigger je Anweisung statt je Zeile; Test 07
- **Lueckenlosigkeit des Nummernkreises ist nicht durchgesetzt: die Anwendungsrolle kann Nummern verbrennen und den Zaehler vorspulen**
  → 0009
- **ON DELETE CASCADE von betrieb ist unerreichbar, sobald ein Beleg festgeschrieben ist**
  → 0013 betrieb_loeschen mit eng gefasster Ausnahme; Test 06
- **Kein Test fuer einen Nutzer in zwei Betrieben — meine_betriebe() darf still auf einen Betrieb schrumpfen**
  → Test 05 Carla in zwei Betrieben

### niedrig (4)

- **journal.id ist eine globale Identity-Sequenz und macht das Schreibaufkommen aller Mandanten messbar**
  → 0015 journal.id nicht mehr an die Anwendungsrolle ausgeliefert; Test 05
- **betriebsrolle wird in keiner Policy ausgewertet — jedes Konto im Betrieb hat Vollzugriff**
  → 0013 Rollenmodell inhaber/buero/monteur; Test 06
- **Belegdatum ist beliebig rueckdatierbar und wird erst nach der Festschreibung eingefroren**
  → 0012 CHECK + 0014 Zukunftsdatum abgewiesen; Test 07
- **journal.betrieb_id ohne Fremdschluessel: nach dem Loeschen eines Betriebs bleiben unloeschbare, fuer niemanden lesbare Waisenzeilen**
  → 0013 betrieb_loeschen raeumt das Journal mit ab; Test 06

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

Startet einen lokalen Postgres, spielt alle Migrationen ein, stellt die
Supabase-Rechtelage her und laesst die Testdateien laufen. Die Dateien unter
`supabase/local/` bilden nach, was Supabase bereits mitbringt, und werden nie
auf ein Supabase-Projekt angewendet.
