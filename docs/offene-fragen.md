# Offene Fragen

Was **nicht** belegt ist. 37 von 129 recherchierten Behauptungen sind in der
adversarialen Verifikation durchgefallen — sie stehen bewusst nicht im Plan.

> Regel: Nichts aus dieser Liste wird implementiert, bevor es gegen eine
> Primärquelle geprüft ist.

---

## Blockierend — vor Schema-Freeze zu klären

### 1. Rechnungs-Datenmodell für Abschlagszahlungen und Einbehalte

**Alle** Aussagen dazu sind durchgefallen: § 14 VOB/B (Prüfbarkeit,
LV-Positionsreihenfolge, Aufmaß-Gegenzeichnung, REB-Format), § 16 VOB/B
(60-Tage-Frist, Verzug), § 17 VOB/B (5 % Vertragserfüllungs- und 5 %
Gewährleistungseinbehalt über 5 Jahre), § 13b UStG Reverse-Charge bei
Bauleistungen.

**Zu klären:** Wie werden Abschlagsrechnungen, Schlusszahlung mit Verrechnung
der Abschläge, Sicherheits- und Gewährleistungseinbehalte sowie
Reverse-Charge so modelliert, dass die erzeugte ZUGFeRD/XRechnung
EN-16931-konform validiert?

**Quellen:** VOB/B-Volltext, UStG, Steuerberater.
**Risiko:** Das ist der wahrscheinlichste Punkt, an dem eine handwerkstypische
Rechnung den KoSIT-Validator nicht besteht.

### 2. DATEV-Exportpfad

Sämtliche DATEV-Claims sind durchgefallen — auch die konkrete
EXTF-Spaltenspezifikation (Headerversion, Formatversion, Spaltenanzahl).
Verifiziert ist **nur**, dass das Prüfprogramm 2.2.3.0 und Musterdaten ohne
Login verfügbar sind.

**Zu klären:** Datei-Export (EXTF-Buchungsstapel) oder Cloud-API mit
Registrierungsprozess? Exakte Spaltenspezifikation aus der heruntergeladenen
Musterdatei `EXTF_Buchungsstapel.csv` ableiten.

**Risiko:** Steuerberater-Export ist bei der Zielgruppe faktisch Kaufkriterium.

### 3. GoBD Rz. 76 — Verzicht auf den PDF-Snapshot

Geteiltes Prüfvotum (2:1). Die Bedingung „jederzeit inhaltlich identisches
Mehrstück erzeugbar" ist der prüfungsrelevante Knackpunkt.

**Zu klären:** Schriftliche Bestätigung durch einen Steuerberater.
**Risiko:** Die gesamte PDF-lose Architektur hängt daran.

---

## Wichtig — vor Produktivsetzung

### 4. Reale Schreiblast

Nicht gemessen: Zeiterfassungseinträge, Belegpositionen und Doku-Datensätze
pro Betrieb und Tag. Ohne Lastmodell ist die Wahl von Postgres über D1 zwar
plausibel begründet, aber nicht quantitativ belegt.

### 5. DATANORM und UGL

Vollständig unbelegt: Spezifikation, Version, Bezugsstelle, Lizenzkosten,
Testdaten. Ebenso offen, welche Großhändler der Zielregion laut
IDS-Connect-Verzeichnis welche Version (2.0/2.3/2.5) unterstützen.

**Risiko:** Ohne das ist das Materialmodul nicht planbar.

### 6. DSGVO und Auftragsverarbeitung

Keine verifizierten Aussagen zu AV-Vertragspflichten, DPA-Lage bei Supabase
und Cloudflare, EU-Hosting-Anforderungen oder Verfahrensdokumentation.

**Risiko:** 96 % der Betriebe nennen Datenschutz als Hemmnis — das ist
verkaufsentscheidend, nicht nur juristisch relevant.

### 7. Supabase Free-Tier — Detailspezifikation

Die vollständige Free-Tier-Spezifikation (500 MB DB, 5 GB Egress, 1 GB
Storage, 50.000 MAU) ist **durchgefallen**. Verifiziert sind nur: Pausierung
nach 1 Woche, max. 2 aktive Projekte, keine Backups, 1 Tag Log-Retention,
50 MB max. Dateigröße.

---

## Nachrangig

### 8. PowerSync-Kosten

Preismodell, Free-Tier-Grenzen und Self-Hosting-Option nicht untersucht.
Erst relevant, wenn die Write-Queue nicht mehr ausreicht.

### 9. Wettbewerberpreise jenseits von plancraft und hero

ToolTime, Sage Handwerk, openHandwerk und Meisterwerk sind durchgefallen.
hero (59 €/22 €) stammt aus einer **Wettbewerber-Quelle** (Meisterwerk-Blog)
und ist ein 2026er Aktionspreis bei Jahresvertrag.

### 10. Ebenfalls durchgefallen — nicht weiterverwenden

- PowerSync-„Bucket"-Skalierung auf Millionen Zeilen
- RLS-Umgehung von Sub-Tabellen-RLS via `SECURITY DEFINER`
- Digitalkompetenz werde **vor** der App-Akzeptanz erworben (Kausalrichtung unbelegt)

---

## Verfallsdaten

Alle Cloudflare-, Vercel- und Supabase-Preise sind **USD netto, Abrufstand
August 2026**. Vercel weist Hobby-Werte ausdrücklich als unverbindliche
Richtwerte aus. Formatversionen (ZUGFeRD 2.5.x, XRechnung 3.0.2, IDS 2.5,
DATEV-Prüfprogramm 2.2.3.0, Mustangproject 2.25.0) altern schnell.

**Vor jeder Architekturentscheidung, die auf einer Zahl aus diesem Plan
beruht: Zahl neu prüfen.**

---

## Nachtrag 25.08.2026 — Recherchelauf zum Rechnungsmodell abgebrochen

Der Versuch, Punkt 1 dieser Liste (Abschlagsrechnungen, Einbehalte, § 13b
Reverse Charge) gegen Primaerquellen zu klaeren, ist **unvollstaendig
abgebrochen**: von 151 Pruefagenten liefen nur 37 durch, 114 scheiterten am
Nutzungslimit der Sitzung.

Die Folge ist wichtig fuer die Bewertung: Der Lauf listet 38 Aussagen als
"verworfen", aber die meisten davon tragen das Votum **0:0** — es wurde also
gar keine gueltige Stimme abgegeben. Das ist ein Infrastrukturfehler, **kein
inhaltliches Ergebnis**. Diese Aussagen sind damit weder belegt noch widerlegt.

**Punkt 1 bleibt unveraendert offen.** Nichts aus jenem Lauf darf ohne erneute
Pruefung ins Datenmodell einfliessen. Das betrifft insbesondere die dort
genannten Fristen, Prozentsaetze und XRechnung-Feldzuordnungen.


---

## Nachtrag 26.08.2026 — Punkt 1 weitgehend geklaert

Der Recherchelauf zum Rechnungsmodell ist beim zweiten Anlauf vollstaendig
durchgelaufen: **151 Agenten, 0 Fehler, 43 von 48 Aussagen belegt** (beim ersten
Versuch waren es 10 von 48, der Rest scheiterte am Nutzungslimit).

Ergebnis in [rechnungsmodell.md](rechnungsmodell.md). **Punkt 1 dieser Liste ist
damit nicht mehr blockierend** — das Schema fuer Abschlagsrechnungen,
Endrechnung, Einbehalte und Reverse Charge steht auf Paragrafen und amtlichen
Erlasstexten.

Die wichtigste Einzelantwort auf die urspruengliche Frage: **Der Einbehalt fasst
den Beleg nie an.** Er ist eine reine Zahlungsmodalitaet und mindert weder
Bemessungsgrundlage noch Umsatzsteuer (§ 10 Abs. 1 Satz 2 UStG, UStAE 17.1
Abs. 3a). Ebenso erzeugt Skonto keinen Beleg, und eine unterzahlte
Abschlagsrechnung keinen Korrekturbeleg.

**Was offen bleibt** (Abschnitt 5 des Dokuments), und warum es das Schema nicht
blockiert:

1. **EN 16931 hat keine strukturierte Zielstelle fuer die Absetzung je
   Abschlag.** BT-113 ist ausdruecklich eine einzige Summe, BG-3 traegt keinen
   Betrag - waehrend das BMF-Schreiben vom 15.10.2025 Rn. 35 alle
   Pflichtangaben im strukturierten Teil verlangt. Eine kursierende
   KoSIT/FeRD-Zuordnung ist in der Gegenpruefung durchgefallen und wird bewusst
   nicht verwendet. Das Datenmodell haelt die Absetzung je Abschlag trotzdem
   vollstaendig vor, damit jede spaetere Darstellungsform daraus gerendert
   werden kann. Frage an den Steuerberater.
2. Rn. 47/48 des BMF-Schreibens vom 15.10.2024 wurden nicht geprueft; zwei
   Darstellungsvarianten sind bis dahin per CHECK gesperrt - konservativ, aber
   lockerbar.
3. ZUGFeRD-Kardinalitaet von `ram:InvoiceReferencedDocument` (Spezifikation nur
   nach Registrierung abrufbar). Betrifft nur den Serialisierer, nicht das Schema.
4. Die Prozentsaetze 5 % und 3 % stammen aus der VOB/A, die nicht auf der
   Quellenliste stand. Deshalb **keine** Default-Prozentsaetze im Schema.
5. Der Begriff "Werktag" in der VOB/B ist in den geprueften Quellen nicht
   definiert - ob Samstag zaehlt, bleibt Parameter.
6. **`lieferant` hat weder Nummer noch Anschrift.** Die Tabelle beschreibt
   bisher nur die Anbindung an den Grosshandel (IDS-Version und -Endpunkt) und
   ob jemand zusaetzlich als Subunternehmer einplanbar ist. Fuer eine Bestellung
   fehlen Anschrift, Kundennummer beim Lieferanten und Ansprechpartner. Beim
   Anlegen der Demodaten aufgefallen. Nachzuholen, sobald der Materialteil
   (Schritt in der Roadmap) drankommt - vorher waeren es Felder ohne Verwender.

7. **Eine Baustelle mit belegten, nicht beauftragten Buchungen laesst sich
   nicht loeschen.** Seit 0021 steht auf `nachweis_id` ein RESTRICT, und
   `dokumentation` haengt per CASCADE am Projekt: der Loeschversuch bricht ab,
   weil eine Zeitbuchung ihren Nachweis noch braucht. Fachlich ist das
   vertretbar - erst klaeren, dann loeschen -, aber die Meldung nennt die
   falsche Tabelle. Heute nur theoretisch: die Anwendung bietet kein Loeschen
   von Projekten an. Wenn sie es tut, muss der Weg lauten "erst die offenen
   Meldungen klaeren", mit genau diesem Satz. Beim Aufraeumen der Pruefdaten
   aufgefallen.

Vier der fuenf verworfenen Aussagen betreffen die EN-16931-Abbildung von
Einbehalten und Anzahlungen. Die Haeufung ist kein Zufall: die Norm hat dort
eine Luecke.
