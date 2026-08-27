# Umsetzungsplan der Anwendung

Neun Schritte von „keine Zeile Anwendungscode" bis zur benutzbaren App, mit dem
Nachtragswächter als tragendem Teil — nicht als Nachrüstung.

Jeder Schritt hat **Fertig wenn** — überprüfbare Bedingungen, keine
Absichtserklärungen. Ein Schritt gilt erst als erledigt, wenn alle erfüllt sind.

---

## Ausgangslage

**Fertig und geprüft:** 18 Migrationen, 20 Tabellen, 9 Testdateien grün.
Mandantentrennung auf Fremdschlüsselebene, GoBD-Festschreibung,
Rechnungsmodell mit Abschlagsabsetzung, Rechtevergabe gehärtet. Design-Tokens
für Tag und Nacht, 9 Ansichten als Artboards.

**Nicht vorhanden:** jede Zeile Anwendungscode.

**Entscheidungen aus [architektur.md](architektur.md)**, hier nicht neu
verhandelt: Next.js App Router als PWA, Cloudflare Pages + Workers via OpenNext,
Supabase Postgres in `eu-central-1`, Fotos nach R2, Offline als Write-Queue mit
client-erzeugten UUIDs.

**Vier Entscheidungen zum Wächter**, in diesem Durchgang getroffen:

| Frage | Entscheidung |
|---|---|
| Buchung ohne Position | **melden und Nachweis verlangen** — Buchung geht durch, Foto oder Notiz ist Pflicht |
| Umfang | **Zeit + Material + Mengenmehrung** über 110 % |
| Bedenkenanzeige | **erzeugen, Versand durch den Betrieb** — kein Mailversand durch uns |
| Anmeldung | **Passwort mit langer Sitzung**, kein Magic Link |

---

## Was im Datenmodell noch fehlt

Beim Durchplanen sind drei echte Lücken aufgefallen — keine davon war vorher
sichtbar.

### 1. Es gibt keine Materialerfassung

`artikel` sind Stammdaten, `beleg_position` ist das *Angebotene*. Was auf der
Baustelle **tatsächlich verbraucht** wird, erfasst bisher nichts. „Material ohne
Position" lässt sich also gar nicht feststellen — die Tabelle dafür existiert
nicht.

→ **Migration 0020:** neue Tabelle `materialentnahme`, gebaut wie `zeiteintrag`:
client-erzeugte `id` (idempotenter Offline-Upload), `projekt_id`,
`artikel_id` (nullable, freie Eingabe erlaubt), `bezeichnung`, `menge`,
`einheit`, **`position_id` nullable** — genau das Signal, das den Wächter
auslöst.

### 2. Ein Nachtrag ist keine Belegart

`beleg_art` kennt Angebot, Auftrag, die drei Rechnungsarten, Gutschrift und
Storno. Ein Nachtrag ist fachlich ein Angebot mit Bezug auf einen bestehenden
Auftrag und gehört als eigene Art hinein — sonst ist er in der Auswertung nicht
von einem normalen Angebot zu trennen.

→ **Migration 0020:** `nachtrag` in `beleg_art`, Präfix `NA-` in
`nummer_praefix()`. Der Bezug zum Hauptauftrag läuft über das vorhandene
`vorgaenger_id`.

### 3. Es gab keinen Weg, ein Konto anzulegen — behoben in 0019

Beim Bau der Anmeldemaske aufgefallen und sofort geschlossen: `betrieb` hatte
seit 0013 **keine INSERT-Policy mehr**. 0013 ersetzte `betrieb_eigene` (`for
all`) durch `betrieb_lesen` (select) und `betrieb_aendern` (update) — INSERT
fiel dabei ersatzlos weg. Dazu sind `benutzer` und `benutzer_betrieb` für die
Anwendungsrolle nur lesbar; 0006 vermerkt „Einladungen laufen über eine
gesonderte Funktion", die es nie gab.

Ergebnis: Niemand konnte sich registrieren, keinen Betrieb gründen, keine
Kollegin aufnehmen. Die gesamte Anwendung hätte auf einem Schema aufgesetzt, das
keinen ersten Benutzer zulässt.

→ **Migration 0019** mit fünf security-definer-Funktionen: `konto_anlegen`,
`betrieb_gruenden`, `mitglied_aufnehmen`, `mitglied_rolle_setzen`,
`mitglied_entfernen`. Test 10 prüft den Weg und die Abwege — unter anderem, dass
niemand sich selbst in einen fremden Betrieb aufnehmen kann und dass der letzte
Inhaber weder zurücktreten noch entfernt werden kann.

### 4. Die Bedenkenanzeige hat keinen Ort

§ 4 Abs. 3 VOB/B verlangt **unverzüglich und schriftlich**. Ein Beweis, der als
Notiz in einem Textfeld liegt, ist keiner.

→ **Migration 0021:** Tabelle `bedenkenanzeige` mit `erstellt_am`,
`versendet_am`, `versandart`, `empfaenger`, Bezug auf Projekt und auslösende
Buchung — und einem Trigger, der sie **ab dem Versand unveränderlich** macht,
nach demselben Muster wie `beleg_unveraenderlich()`.

> **Achtung, Folge aus 0017:** seit der Rechtehärtung erben neue Tabellen
> **keine** Rechte mehr. Jede dieser Migrationen muss `grant select, insert,
> update, delete ... to authenticated` selbst mitbringen, sonst ist die Tabelle
> für die Anwendung unsichtbar. Test 09 fängt das Gegenteil ab (zu viele
> Rechte), nicht den Fall „vergessen" — deshalb hier ausdrücklich notiert.

---

## Die neun Schritte

### Anlauf: 1 bis 5

Der Wächter braucht ein Leistungsverzeichnis, eine Buchung und einen
Nachweiskanal. Diese fünf Schritte sind kein Vorspiel, sondern seine
Voraussetzung.

---

### Schritt 1 — Gerüst und Anmeldung ✓ erledigt

Live: **https://gewerk-crm.f3x.workers.dev**

**Ziel:** Eine angemeldete Person sieht ihren Betrieb und sonst nichts.

**Inhalt**
- Next.js App Router, OpenNext, Deploy auf Cloudflare Pages + Workers
- Supabase Auth mit Passwort, lange Sitzung, Sitzung überlebt Appneustart
- `tokens.css` und `basis.css` eingebunden, Tag/Nacht folgt dem Gerät, manuell umschaltbar
- Betriebsauswahl, wenn jemand zu mehreren gehört (das Modell erlaubt es)
- Navigation je Rolle: Monteur sieht Zeit und Doku, Büro zusätzlich Belege, Inhaber alles

**Fertig wenn**
- Anmelden, abmelden, Neuladen hält die Sitzung
- Ein E2E-Test meldet zwei Nutzer aus verschiedenen Betrieben an und belegt, dass keiner Daten des anderen sieht
- Ein Test schlägt fehl, sobald `SUPABASE_SERVICE_ROLE_KEY` im Client-Bundle auftaucht
- Deploy läuft aus dem Repo, die Seite ist über eine URL erreichbar

**Fallstrick:** Der `service_role`-Schlüssel darf nie in den Client. Die gesamte
Mandantentrennung hängt daran, dass jeder Zugriff als `authenticated` läuft und
damit durch RLS. Deshalb ist das ein Test, keine Konvention.

**Am 26.08.2026 gegen die ausgerollte Fassung geprüft:** Umleitung ohne
Anmeldung, Stylesheet und Schriften werden ausgeliefert, Tokens für Tag und
Nacht sind enthalten, kein Dienstschlüssel im tatsächlich ausgelieferten
JavaScript, und die Laufzeitprotokolle des Workers zeigen `ok` ohne Ausnahmen —
der Worker erreicht Supabase.

Offen blieb allein die erste echte Registrierung; sie legt das erste Konto im
Projekt an und gehört deshalb dem Betreiber, nicht dem Prüflauf.

---

### Schritt 2 — Kunden und Projekte ✓ erledigt

**Ziel:** Das Bedienmuster einmal richtig bauen, an der einfachsten Stelle.

**Inhalt**
- Liste, Detail, Anlegen, Ändern für `kunde` und `projekt`
- Das wiederverwendbare Muster: Ladezustand, Leerzustand, Fehlerzustand, Speicherzustand
- Suche über Name und Nummer

**Fertig wenn**
- Kunde und Projekt anlegen, ändern, in der Liste finden
- Ein Formularfehler aus der Datenbank (z. B. doppelte Kundennummer) erscheint verständlich am Feld, nicht als roter Kasten mit SQL-Text
- Das Muster liegt in Komponenten, die Schritt 3 bis 9 benutzen

**Fallstrick:** Hier entsteht das Vokabular für alles Weitere. Zwei Tage mehr an
dieser Stelle sparen zwei Wochen später.

**Abgenommen am 27.08.2026:** 12 Oberflächentests grün, davon 7 mit echter
Anmeldung gegen das Projekt. Zwei davon belegen die Mandantentrennung **durch
die Oberfläche**: ein fremder Kunde liefert 404, und B sieht die Kunden von A
nicht in der Liste. Die Prüfkonten `pruefer-a@example.com` und
`pruefer-b@example.com` gehören zur Testeinrichtung und legen sich selbst an;
angelegte Datensätze räumen die Tests über die Anwendungsrolle wieder ab.

---

### Schritt 3 — Angebot und Auftrag mit Positionen ✓ erledigt

**Ziel:** Das Leistungsverzeichnis entsteht. **Ohne diesen Schritt gibt es
nichts, wogegen der Wächter prüfen könnte.**

**Inhalt**
- Positionen erfassen: Leistung, Material, Text, Titel; Menge, Einheit, Einzelpreis
- Kalkulationsanteile je Einheit (Lohn, Material, Fremdleistung, Lohnminuten) — die Grundlage jeder späteren Nachkalkulation
- Angebot in Auftrag wandeln
- Festschreiben über `beleg_festschreiben()`, danach zeigt die Oberfläche den Beleg als gesperrt

**Fertig wenn**
- Angebot mit mindestens 10 Positionen inkl. Titelzeilen erfassbar
- Festschreiben vergibt `AN-2026-00001`; ein zweites Festschreiben desselben Belegs wird abgewiesen und die Meldung ist verständlich
- Nach dem Festschreiben ist keine Position mehr änderbar — die Oberfläche bietet es gar nicht erst an
- Summen im Client stimmen mit `beleg.netto/steuer/brutto` überein (kaufmännisch je Position gerundet, dann summiert)

**Fallstrick:** Die Summen dürfen **nicht** im Client gerechnet und gespeichert
werden. Die Datenbank rechnet, der Client zeigt. Weicht der Client ab, ist der
Client falsch.

**Abgenommen am 27.08.2026:** 16 Oberflächentests grün. Belegt sind: Summen aus
`beleg.netto/steuer/brutto` gegen eine Handrechnung (820,00 / 155,80 / 975,80),
Festschreiben vergibt `AN-2026-00001` und sperrt die Oberfläche, eine bloße
Titelzeile wird als „keine abrechenbare Position" abgewiesen, und aus dem
Angebot entsteht ein Auftrag mit eigenem Präfix `AU-` und übernommenen
Positionen.

---

### Schritt 4 — Zeiterfassung mit Positionsbezug ✓ erledigt

**Ziel:** Der Erfassungspunkt, an dem der Wächter später ansetzt.

**Inhalt**
- Monteursansicht: Projekt wählen → Position wählen → starten/stoppen
- **„Keine passende Position"** ist ein gleichwertiger, sichtbarer Knopf neben der Positionsliste — kein versteckter Notausgang. Wer ihn drückt, hat nichts falsch gemacht; er meldet nur, dass das LV die Arbeit nicht abdeckt
- Offline-Warteschlange in IndexedDB, client-erzeugte UUIDs, Statusanzeige („3 Einträge warten")
- Nacherfassung für vergangene Tage (§ 17 MiLoG erlaubt 7 Tage)

**Fertig wenn**
- Zeit im Flugmodus erfassen, Netz einschalten, Eintrag erscheint serverseitig
- Derselbe Eintrag zweimal gesendet erzeugt **einen** Datensatz (client-UUID als Primärschlüssel)
- App schließen und neu öffnen verliert keinen Eintrag aus der Warteschlange
- Der Weg „Projekt → Position → läuft" braucht höchstens drei Berührungen

**Fallstrick:** Wird „keine passende Position" umständlicher gestaltet als die
Positionsauswahl, wählen die Monteure irgendeine Position — und der Wächter
verhungert. Der Knopf muss **genauso leicht** erreichbar sein.

**Abgenommen am 27.08.2026:** 19 Oberflächentests grün. Ein Test misst die
Knopfgrößen und schlägt fehl, sobald „Keine passende Position" schmaler oder
niedriger wird als eine Position. Der Offline-Test erfasst im Flugmodus,
schaltet das Netz zu und zählt in der Datenbank nach: genau ein Datensatz.

Drei echte Mängel kamen dabei ans Licht, alle drei erst beim Ausprobieren:
ein erfasster Eintrag wurde nie von selbst gesendet (nur bei Appstart oder
Netzrückkehr), er verschwand bis zur Übertragung aus der Ansicht, und
`router.refresh()` warf die Seite im Funkloch auf die Fehlerseite des Browsers.

---

### Schritt 5 — Fotos, Notizen, R2 ✓ erledigt

**Ziel:** Der Nachweiskanal. Ohne ihn kann Schritt 6 keinen Nachweis verlangen.

**Inhalt**
- Foto aufnehmen, clientseitig auf ~500 KB komprimieren, in die Warteschlange
- Upload nach R2 über kurzlebige, signierte URLs; in der Datenbank steht nur der Objektschlüssel
- Notiz und Aufmaß je Projekt
- Anzeige im Projekt, chronologisch

**Fertig wenn**
- Foto offline aufnehmen, später hochladen, im Projekt sichtbar
- Kein öffentlich lesbarer Bucket; eine URL ohne Signatur liefert 403
- `erfasst_am` kommt vom Gerät, `hochgeladen_am` vom Server — beide sichtbar, wenn sie auseinanderliegen

**Belegt durch**
- `web/e2e/05_doku.spec.ts`, vier Prüfungen. Drei davon laufen nur gegen die
  Worker-Fassung (`playwright.worker.ts`): die R2-Bindung gibt es allein in der
  workerd-Laufzeit, unter `next start` fehlt sie. Im lokalen Lauf werden sie
  ausdrücklich übersprungen, statt eine Umgebungslücke als Anwendungsfehler
  auszugeben.
- Foto ohne Netz: das Bild wartet als Blob in IndexedDB mit. Beim Senden geht
  erst die Datei in den Speicher, dann die Zeile — und der Schlüssel wird
  sofort in die Warteschlange zurückgeschrieben, damit ein zweiter Versuch kein
  zweites Objekt ablegt.
- Der Bucket ist nicht öffentlich. Ausgeliefert wird nur über
  `/api/dokument?k=…`; ein Schlüssel aus einem fremden Betrieb wird abgewiesen,
  **bevor** der Bucket gefragt wird (erstes Segment ist die `betrieb_id`).
- `hochgeladen_am` steht neben `erfasst_am`, sobald die beiden auf
  verschiedene Tage fallen.

> **Vorbereitung:** R2 ist freigeschaltet (26.08.2026) — die Bucket-Liste
> antwortet, kein Fehler 10042 mehr. Der Bucket selbst wird im Dashboard **mit
> Jurisdiktion EU** angelegt; der MCP-Connector kann das nicht, und die
> Jurisdiktion ist nach dem Anlegen unveränderlich. Bindung und S3-Endpunkt
> tragen sie dann ebenfalls — siehe [architektur.md](architektur.md),
> „EU-Jurisdiktion: einmalig und unumkehrbar".

---

### Der Wächter: 6 und 7

---

### Schritt 6 — Nachtragswächter, Teil 1: Erkennen ✓ erledigt

**Ziel:** Der Betrieb erfährt **am selben Tag**, dass jemand etwas gemacht hat,
das nicht beauftragt ist.

**Inhalt**

*Migrationen 0020 und 0021* wie oben beschrieben.

*Drei Regeln:*

| # | Regel | Grundlage |
|---|---|---|
| 1 | Zeitbuchung ohne `position_id` | keine — schlicht nicht beauftragt |
| 2 | Materialentnahme ohne `position_id` | dito |
| 3 | Ist-Menge über **110 %** der Soll-Menge | § 2 Abs. 3 Nr. 2 VOB/B |

*Nachweispflicht:* Wer „keine passende Position" wählt, muss ein Foto oder eine
Notiz mitgeben, bevor die Buchung in die Warteschlange geht. Auf der Baustelle
kostet das zehn Sekunden; vier Wochen später ist es nicht mehr zu beschaffen.

*Büroansicht „Ungeklärt":* eine Liste, nach Projekt gruppiert, mit Betrag in
Euro (Stunden × Verrechnungssatz, Material × Einkaufspreis). Nicht „7 Meldungen",
sondern **„1.240 € nicht beauftragt"**. Die Zahl ist die Botschaft.

**Fertig wenn**
- Alle drei Regeln haben einen Datenbanktest in `supabase/tests/`, der sie an echten Zeilen belegt
- Eine Buchung ohne Position lässt sich **nicht** ohne Foto oder Notiz abschließen
- Die Büroansicht zeigt eine heute erfasste Buchung noch heute
- Der Eurobetrag stimmt mit einer Handrechnung überein

**Ehrliche Grenze bei Regel 3.** Die 110-%-Prüfung funktioniert nur, wo die
Einheiten vergleichbar sind:

- Materialposition in Stk/m/kg gegen `materialentnahme.menge` → **vergleichbar**
- Lohnposition in Stunden gegen erfasste Zeit → **vergleichbar**
- Position in m² oder m³ („Wand verputzen, 120 m²") → **nicht ableitbar.** Aus
  Stunden folgt keine Fläche.

Für diese Positionen braucht es einen von Hand gepflegten Leistungsstand. Der
kommt **nicht** in Schritt 6 — er ist ohnehin die Grundlage der
Abschlagsautomatik nach § 632a BGB und gehört dorthin. Regel 3 läuft also
zunächst nur, wo die Einheit passt, und sagt das in der Oberfläche auch.

**Fallstrick:** Zu viele Meldungen sind so schlecht wie keine. Deshalb
Euro-Schwelle statt Zählung, Gruppierung je Projekt, und ein Weg, eine Meldung
mit Begründung als „geklärt" abzulegen — die Begründung landet im Journal.

**Belegt durch**
- `supabase/tests/11_nachtragswaechter.sql`: drei Regeln an echten Zeilen, dazu
  die beiden Nichtfälle (105 % meldet nicht; eine m²-Position wird nicht aus
  Stunden beurteilt), die Nachweispflicht, die Handrechnung 192,50 + 30,00 +
  124,00 = 346,50 € und die Mandantengrenze **der Sichten** — ohne
  `security_invoker` liefert eine Sicht alle Mandanten aus.
- Fünf Mutationen gegengeprüft: Schwelle 110 → 104 %, `security_invoker`
  entfernt, beide Nachweisregeln entschärft, Betragsformel verfälscht. Jede
  wurde gefangen.
- `web/e2e/06_waechter.spec.ts`: „Stopp" bleibt ohne Nachweis gesperrt, eine
  nachgetragene Schicht erscheint mit 510,00 € (8,5 Std × 60,00) im Büro, und
  Ablegen ohne Begründung geht nicht.

**Drei Befunde aus der Nachprüfung, jeweils mit Migration behoben**
- *0021:* `on delete set null` auf `nachweis_id` ließ Postgres den Verweis
  leeren; erst die Prüfregel fing es ab — mit einer Meldung über `zeiteintrag`,
  obwohl eine Notiz gelöscht werden sollte. Jetzt RESTRICT: „wird noch
  verwendet", und die verweisende Tabelle steht dabei.
- *0022:* Ein einmal gebuchter Artikel war nie wieder löschbar, weil die
  Entnahme ihre Bezeichnung aus dem Stammsatz bezog. Sie trägt sie jetzt selbst
  — genau wie den Einkaufspreis, und aus demselben Grund.
- *Warteschlange:* Sie hing an den drei Erfassungsformularen. Wer nach dem
  Buchen sofort weiterklickte, brach die Übertragung ab, und auf jeder anderen
  Seite gab es nichts, was sie wieder aufgenommen hätte. Sie steht jetzt im
  Layout. Der Prüflauf fiel dadurch von 30 auf 8 Sekunden — er hatte vorher
  jedes Mal auf eine Übertragung gewartet, die niemand mehr anstieß.

---

### Schritt 7 — Nachtragswächter, Teil 2: Handeln ✓ erledigt

**Ziel:** Von der Meldung zum abrechenbaren Nachtrag in unter zwei Minuten.

**Inhalt**
- Aus einer oder mehreren ungeklärten Buchungen einen **Nachtrag** erzeugen: Positionen entstehen aus den Ist-Mengen, die Beweisfotos hängen dran, der Bezug auf den Hauptauftrag steht in `vorgaenger_id`
- **Bedenkenanzeige § 4 Abs. 3 VOB/B** als PDF: Bezug, Datum, Sachverhalt, Fotos, Unterschriftsfeld
- Versand durch den Betrieb; die App hakt „versendet am / wie / an wen" ab und friert den Datensatz damit ein
- Die betroffenen Buchungen wechseln von „ungeklärt" auf „im Nachtrag NA-2026-00003"

**Fertig wenn**
- Meldung → Nachtrag → festgeschrieben → PDF in unter zwei Minuten, an echten Daten gemessen
- Ein versendeter Nachweis ist nicht mehr änderbar (Datenbanktest, nicht nur UI)
- Der Nachtrag taucht in der Schlussrechnung auf und wird korrekt abgesetzt — das prüft der vorhandene Absetzungs-Trigger bereits

**Fallstrick:** Ab 110 % ist laut BGH nicht mehr die ursprüngliche
Preisermittlung maßgeblich, sondern die **tatsächlich erforderlichen Kosten** der
Mehrmenge. Die App darf den alten Einheitspreis also nicht stillschweigend
fortschreiben — sie muss zur Eingabe der tatsächlichen Kosten auffordern und
kenntlich machen, warum.

**Belegt durch**
- `supabase/tests/12_nachtrag.sql`: aus zwei Meldungen werden zwei Positionen
  mit den Ist-Mengen, die Buchungen hängen danach daran, `vorgaenger_id` zeigt
  auf den Hauptauftrag, ohne Preis bricht das Festschreiben ab, mit Preis
  kommt `NA-2026-00001` heraus, und der Nachtrag zählt im Leistungsstand als
  Soll — sonst meldete der Wächter die Mehrmenge, die er gerade zum Nachtrag
  gemacht hat, sofort wieder.
- `web/e2e/07_nachtrag.spec.ts`: derselbe Weg durch die Oberfläche, vom Haken
  an der Meldung bis zum versendeten Schriftstück — **19 Sekunden**, gemessen,
  nicht geschätzt. Die zwei Minuten aus dem Ziel sind komfortabel eingehalten.
- Die Unveränderlichkeit ist an der Datenbank geprüft, nicht nur am Formular:
  ein `update` auf eine versendete Anzeige scheitert auch am direkten Zugriff.

**Die Preispflicht steht in der Datenbank.** Jede Nachtragsposition entsteht mit
Preis null; ein Trigger lässt das Festschreiben erst zu, wenn jemand die
tatsächlich erforderlichen Kosten eingetragen hat. Eigener Trigger statt
Änderung an `beleg_festschreiben` — und weil der Abbruch die ganze Transaktion
zurückrollt, entsteht dabei keine Lücke im Nummernkreis.

**Zwei Befunde aus der Nachprüfung**
- *`bedenken_versand_vollstaendig` griff nicht.* `btrim(null) <> ''` ergibt
  NULL, und eine CHECK-Regel gilt als erfüllt, sobald ihr Ausdruck NULL ist —
  `versendet_am` ließ sich allein setzen, also „versendet, aber niemand weiß
  wie und an wen". `coalesce` davor. Der Datenbanktest hat es gefunden.
- *pdf-lib läuft bei abgeschnittenen PNG-Daten in eine Endlosschleife.*
  Gemessen: ein gültiges PNG ist in 7 ms eingebettet, ein halbiertes kehrt nach
  20 Sekunden noch nicht zurück — kein Fehler, keine Ausnahme. In einem Worker
  hängt damit die Anfrage, bis die Laufzeit sie abräumt. Ein halb hochgeladenes
  Foto hätte die ganze Bedenkenanzeige lahmgelegt. `bildTaugt()` prüft jetzt
  vorher Kennung und vollständigen Aufbau; `web/e2e/09_pdf_bilder.spec.ts`
  hält das fest.

**Nebenbei:** `getCloudflareContext()` wirft außerhalb der Worker-Laufzeit,
statt eine leere Umgebung zu liefern — aus einem fehlenden Dateispeicher wurde
so ein Serverfehler 500. `lib/dateispeicher.ts` fängt das einmal zentral ab:
ohne Bucket entsteht das Schriftstück trotzdem, nur ohne Bilder.

---

### Ausbau: 8 und 9

---

### Schritt 8 — Rechnung, PDF, E-Rechnung ✓ erledigt

**Ziel:** Geld anfordern, rechtssicher.

**Inhalt**
- Abschlags-, Teil- und Schlussrechnung aus dem Auftrag; Anrechnung der Abschläge
- PDF-Visualisierung und ZUGFeRD 2.0.1 BASIC aus **denselben** Daten
- Zahlungen erfassen, Zahlungsstand je Beleg

**Fertig wenn**
- Schlussrechnung mit zwei Abschlägen: Absetzung stimmt, § 14c-Trigger greift bei Fehlversuch
- Die erzeugte XML besteht einen externen Validator (manuell, der Java-Validator bleibt vertagt)
- PDF und XML weichen inhaltlich nicht voneinander ab — gleiche Quelle, ein Test vergleicht sie

**Belegt durch**
- `supabase/tests/13_rechnungsweg.sql`: Abschlag über 10.000 € netto, vereinnahmt,
  Schlussrechnung über 25.000 €. Ohne Absetzung bricht das Festschreiben ab —
  genau der Fehler, der die Umsatzsteuer auf die Anzahlung ein zweites Mal
  kostet. Mit Absetzung: `RE-2026-00001`, Zahlbetrag 17.850,00 €, und ein
  zweiter Aufruf verdoppelt nichts.
- `web/e2e/10_rechnung.spec.ts` vergleicht nicht nur „inhaltlich": der im PDF
  eingebettete Datensatz wird ausgepackt und **zeichengleich** gegen den
  ausgelieferten XML-Endpunkt geprüft. Auseinanderlaufen ist damit nicht mehr
  eine Frage der Disziplin, sondern ausgeschlossen.
- Dazu: Wohlgeformtheit des XML und die Rechenprobe am Datensatz selbst
  (netto + steuer = brutto, brutto − angerechnet = zahlbar).

**Am erzeugten PDF nachgesehen, zwei Befunde**
- *Das Eurozeichen fehlte auf jeder Rechnung.* Der Zeichenfilter ließ Latin-1
  durch, aber WinAnsi ist nicht Latin-1: zwischen 0x80 und 0x9F hat es eigene
  Zeichen, darunter €. Aus „25.000,00 €" wurde „25.000,00". Nur beim Lesen
  eines echten PDF zu sehen — kein Test hätte darauf angeschlagen, weil die
  Ziffern ja stimmten.
- *Die Summenaufstellung stand linksbündig* und ließ sich nicht überschlagen.
  Jetzt rechtsbündig untereinander.

**Offen und benannt:** das PDF ist noch kein PDF/A-3 (eingebettete Schrift,
Output Intent, XMP fehlen) — siehe [offene-fragen.md](offene-fragen.md) Punkt 8
und 9.

---

### Schritt 9 — Übersicht und Fristen ✓ erledigt

**Ziel:** Der Inhaber sieht morgens, was Geld kostet.

**Inhalt**
- Dashboard: nicht beauftragte Leistung in Euro, offene Posten, Zahlungsstand
- Fristenwächter: Gewährleistung, Freistellungsbescheinigung, Sicherheitseinbehalt, Skonto
- Nachkalkulation je Projekt: geplant gegen tatsächlich

**Fertig wenn**
- Jede Kennzahl ist bis auf die einzelne Zeile aufklappbar
- Keine Zahl ohne Herkunft

**Belegt durch**
- Migration 0026: `abnahme` (das Ereignis, an dem die Gewährleistung hängt),
  `freistellungsbescheinigung` (§ 48b EStG) und drei Sichten — `offene_posten`,
  `fristen`, `nachkalkulation`. Alle drei liefern **Zeilen, keine Summen**;
  summiert wird erst in der Anzeige, damit sich jede Zahl aufklappen lässt.
- `supabase/tests/14_fristen.sql` rechnet jede Kennzahl gegen eine Handrechnung
  nach und prüft die Mandantengrenze der Sichten.
- Vier Mutationen gegengeprüft: `security_invoker` entfernt, Skonto vom Brutto
  statt vom offenen Betrag, VOB-Gewährleistung von vier auf zwei Jahre, und
  Zahlungen ohne Skontoanteil gezählt.
- `web/e2e/11_uebersicht.spec.ts` klappt die Karten wirklich auf, folgt einer
  Zeile bis zum Beleg und prüft, dass die Herkunft die Grundlage nennt
  (§ 48b EStG, Sicherheitsnummer, Abnahmedatum).

**Die vierte Mutation kam zunächst durch** — der Test hatte keine mit Skonto
beglichene Rechnung. Ohne den Skontoanteil bliebe eine vollständig bezahlte
Rechnung für immer als teilweise offen stehen und im Mahnlauf. Der Fall steht
jetzt im Test.

**Beim Ansehen der fertigen Seite geändert:** die Fristenkarte zeigte nur
Zahlungsziele — dieselben Rechnungen, die daneben schon unter „Offene Posten"
standen. Zwei Karten, dieselbe Forderung, und am Ende traut man keiner von
beiden. Auf der Übersicht bleibt das Zahlungsziel deshalb weg; in der Sicht
`fristen` ist es enthalten, denn eine Frist ist es.

**Zur Freistellungsbescheinigung, ausdrücklich:** die Anwendung fragt **nicht**
automatisch beim BZSt ab. Das EIBE-Portal ist ein Portal mit Registrierung,
keine offene Schnittstelle. Geführt werden Sicherheitsnummer und Ablauf, und
erinnert wird rechtzeitig — das ist der ehrliche Funktionsumfang, und er steht
so auch im Migrationskommentar, damit später niemand eine Prüfung vermutet, die
es nicht gibt.

---

## Warum diese Reihenfolge

Der Wächter steht an Position 6, obwohl er das Wichtigste ist. Das ist kein
Zurückstellen, sondern seine Abhängigkeit: Er braucht ein Leistungsverzeichnis
(3), eine Buchung mit Positionsbezug (4) und einen Nachweiskanal (5). Vorher
lässt er sich nicht bauen, nur behaupten.

Nach Schritt 7 ist die App **verkaufbar**, auch ohne 8 und 9 — sie tut dann
genau das, was sonst niemand tut.

---

## Was bewusst draußen bleibt

| | Warum |
|---|---|
| Abschlagsautomatik § 632a BGB | Braucht den händischen Leistungsstand aus Schritt 6/9. Direkt danach der nächste große Hebel. |
| Eingangsrechnungen | Wertvoll und billig, aber kein Alleinstellungsmerkmal. Nach Schritt 8. |
| Open Masterdata / Datanorm | Integrationsarbeit mit vielen Partnern. Späterer Burggraben. |
| GAEB-Import | Haben alle Wettbewerber. Nötig für öffentliche Aufträge, kein Vorsprung. |
| Disposition, Material-Lagerverwaltung | Artboards existieren, Nutzen ist gegenüber dem Wächter gering. |
| DATEV-Export | Erst wenn ein echter Betrieb einen Steuerberater mitbringt. |

---

## Offene Punkte

1. ~~R2 freischalten~~ — erledigt am 26.08.2026. Offen ist nur noch der Bucket
   selbst, anzulegen mit **Jurisdiktion EU**.
2. ~~Verrechnungssatz je Mitarbeiter fehlt~~ — **falsch notiert.**
   `mitarbeiter.stundensatz numeric(14,2)` existiert seit 0002. Für den
   Eurobetrag in Schritt 6 ist nichts zu ergänzen.
3. **Kein Artboard für „Ungeklärt"** — die wichtigste Ansicht der App hat noch
   kein Bild. Sollte vor Schritt 6 entworfen werden.
4. **Steuerberater** vor den ersten echten Rechnungen; Fragenliste liegt in
   [rechnungsmodell.md](rechnungsmodell.md), Abschnitt 4.

---

## Quellen

- [§ 2 Abs. 3 Nr. 2 VOB/B — Vergütungsanpassung bei Mengenmehrungen](https://www.anwalt.de/rechtstipps/verguetungsanpassung-bei-mengenmehrungen-gemaess-2-abs-3-nr-2-vobb_160432.html)
- [BGH: bei Mehrmengen sind die tatsächlich erforderlichen Kosten maßgeblich](https://www.vob-online.de/de/bei-mehrmengen-i-s-v-2-abs-3-nr-2-vob-b-sind-die-tatsaechlich-erforderlichen-kosten-zuzueglich-angemessener-zuschlaege-massgeblich-719122)
- [Nachträge im Bauvertrag: § 2 VOB/B richtig anwenden](https://vergabescanner.de/blog/nachtraege-vob-b-paragraph-2/)
- [Aufzeichnungspflicht nach § 17 MiLoG](https://www.avetiq.de/ratgeber/aufzeichnungspflicht-milog/)
