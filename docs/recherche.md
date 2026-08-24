# Recherche-Ergebnisse

Verifizierte Faktenlage, Stand 2026-08-24. Grundlage aller Architektur- und
Produktentscheidungen. Jede Aussage nennt Konfidenz und Quelle.

> Was hier **nicht** steht, ist nicht belegt. 37 von 129 extrahierten
> Behauptungen sind in der adversarialen Prüfung durchgefallen — siehe
> [offene-fragen.md](offene-fragen.md).

---

## 1. Rechtlicher Rahmen — E-Rechnung

| Datum | Was gilt | Konfidenz |
|---|---|---|
| **seit 01.01.2025** | **Empfangspflicht** für alle inländischen Unternehmen, **ohne Übergangsfrist**. Technisch genügt ein E-Mail-Postfach. PDF-Rechnungen nur noch **mit Zustimmung des Empfängers**. | hoch |
| bis 31.12.2026 | Alle Aussteller dürfen weiterhin Papier/PDF verwenden | hoch |
| **01.01.2027** | **Ausstellungspflicht** bei Vorjahresumsatz > 800.000 € | hoch |
| 01.01.2028 | Ausstellungspflicht bei Vorjahresumsatz ≤ 800.000 € | hoch |

Quellen: [BMF-FAQ E-Rechnung](https://www.bundesfinanzministerium.de/Content/DE/FAQ/e-rechnung.html),
[BMF-Schreiben 15.10.2025](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Umsatzsteuer/Umsatzsteuer-Anwendungserlass/2025-10-15-einfuehrung-obligatorische-e-rechnung.pdf) (GZ III C 2 - S 7287-a/00019/007/243)

> **Planungsmarke: 01.01.2027.** Ein Betrieb mit 10–50 Mitarbeitern liegt
> voraussichtlich über 800.000 € Umsatz. Das ist eine plausible Annahme,
> **keine belegte Tatsache** — die Frist hängt am Umsatz des einzelnen
> Betriebs und ist pro Kunde zu bestimmen.

### Zulässige Formate (Konfidenz: hoch)

- **XRechnung** (rein strukturiert) und **ZUGFeRD/Factur-X ab 2.0.1**
- **Ausgenommen: Profile MINIMUM und BASIC-WL** — diese erfüllen die Anforderungen *nicht*
- Mindest-Implementierungsziel: **ZUGFeRD 2.0.1 BASIC** oder höher (EN 16931/COMFORT, EXTENDED)
- Die Aufzählung in UStAE 14.1 Abs. 13/14 ist **nicht abschließend**: jedes EN-16931-konforme Format ist zulässig
- Bei Hybridformaten ist **der XML-Teil rechtlich führend**; weicht das PDF-Layout inhaltlich ab, droht ein Vorsteuerabzugsrisiko

### Validierung (Konfidenz: hoch)

Das BMF unterscheidet **Formatfehler** (Rn. 6a — die Datei ist dann keine
E-Rechnung, sondern nur eine „sonstige Rechnung") von **Geschäftsregelfehlern**
(Rn. 6b). Bei kaufmännischer Sorgfalt darf man sich auf das Ergebnis einer
geeigneten Validierungsanwendung verlassen; die Aufbewahrung des
Validierungsberichts wird empfohlen. Rein technische Geschäftsregelfehler ohne
umsatzsteuerlichen Bezug (Beispiel im Schreiben: fehlendes `BT-10 Buyer
reference`) sind umsatzsteuerlich unbeachtlich (Rn. 35a).

---

## 2. GoBD — die architektonisch wichtigste Erkenntnis

**GoBD-Novelle vom 14.07.2025** (GZ IV D 2 - S 0316/00128/005/088), Anwendung ab
14.07.2025 (neue Rz. 185). Vier zusammenhängende Änderungen legitimieren eine
**datenbankgetriebene, PDF-lose Rechnungsarchitektur**:

| Rz. | Inhalt | Konfidenz |
|---|---|---|
| **76** | Bei Einsatz eines Fakturierungsprogramms muss **keine bildhafte Kopie** der Ausgangsrechnung gespeichert werden — sofern jederzeit auf Anforderung ein **inhaltlich identisches Mehrstück** erzeugt werden kann | mittel (2:1) |
| **119** | Bei E-Rechnungen genügt die Aufbewahrung des **strukturierten Teils**; der PDF-Teil nur, wenn er zusätzliche steuerlich relevante Informationen enthält (z. B. Buchungsvermerke) | hoch |
| **118** | Für strukturiert empfangene Belege genügt **inhaltliche statt bildlicher** Übereinstimmung (abweichend von § 147 Abs. 2 Nr. 1 AO) | hoch |
| — | Eingehende Belege im **Empfangsformat** aufbewahren. Der XML-Teil darf **nicht** durch Formatkonvertierung gelöscht werden. OCR-Anreicherungen sind nach Verifikation ebenfalls aufzubewahren | hoch |

Quelle: [BMF-Schreiben 14.07.2025](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Weitere_Steuerthemen/Abgabenordnung/2025-07-14-GoBD-2-aenderung.pdf)

> **Konsequenz für den Bau:** Rechnungen können als normalisierte Datensätze in
> Postgres liegen. Kein PDF-Snapshot pro Beleg nötig. Das spart erheblich
> Speicher und Komplexität.
>
> **Aber:** Rz. 76 hat ein geteiltes Prüfvotum (2:1), und die Bedingung
> „jederzeit inhaltlich identisches Mehrstück erzeugbar" ist der
> prüfungsrelevante Knackpunkt. Diese Architekturentscheidung **vor
> Produktivsetzung schriftlich mit einem Steuerberater absichern.**

### Aufbewahrung (Konfidenz: hoch)

§ 14b Abs. 1 UStG: **acht Jahre**, bei E-Rechnungen zumindest der strukturierte
Teil unversehrt in ursprünglicher Form. Speicherung außerhalb eines
GoBD-konformen DV-Systems begründet **für Umsatzsteuerzwecke** keinen Verstoß —
die AO/GoBD-Pflichten bleiben davon unberührt.

---

## 3. Werkzeuge — alles lizenzkostenfrei

| Werkzeug | Lizenz | Version (Stand) | Zweck |
|---|---|---|---|
| [Mustangproject](https://www.mustangproject.org/) | Apache-2.0, kommerziell frei | 2.25.0 (05.08.2026) | ZUGFeRD/Factur-X/XRechnung erzeugen, lesen, konvertieren, validieren |
| [KoSIT Validator](https://github.com/itplr-kosit/validator) | Apache-2.0 | v1.6.0 | Amtliche Validierungs-Engine |
| [KoSIT Konfiguration](https://github.com/itplr-kosit/validator-configuration-xrechnung) | Apache-2.0 | v2026-01-31, zielt auf XRechnung 3.0.x | Schematron-Regelwerk EN 16931 + CIUS XRechnung |
| [pyGAEB](https://github.com/frameIQ/pygaeb) | MIT | 1.16.3 (13.08.2026) | GAEB DA XML |
| DATEV-Prüfprogramm | frei, ohne Login | 2.2.3.0 | Testen des Buchungsstapel-Exports |

**Zwei Fallstricke:**

1. **Mustangproject und KoSIT sind JVM-basiert** (Java ≥ 11). Ein Node/Next.js-
   oder Cloudflare-Workers-Stack kann sie **nicht in-process** aufrufen — es
   braucht einen Java-Sidecar, CLI-Subprozess oder gehosteten Dienst.
   *Deshalb ist die Validierung im MVP vertagt.*
2. Bei Mustangproject ist **Bibliothek und CLI kostenlos**, der „Mustangserver"
   (REST) ist die kostenpflichtige Variante. Der Nulltarif-Pfad ist das Jar
   bzw. der CLI-Aufruf.

---

## 4. Handwerks-Schnittstellen

### IDS Connect (Konfidenz: hoch)

**Integrierte Daten-Schnittstelle** — verbindet Handwerkersoftware mit
Großhandels-Onlineshops. Entwickelt von der ITEK GmbH im Auftrag von BVBS,
DG Haustechnik und ZVSHK. Schwerpunkt SHK.

- **Aktuelle Version 2.5**, abwärtskompatibel zu 2.0 und 2.3 (beide im Markt verbreitet)
- Drei Aufrufe: Shop-Suche aufrufen · Artikeldetails abrufen · Warenkörbe empfangen/senden
- Zusätzlich „Artikel-Deep-Link" für tagesaktuelle Preise und Verfügbarkeit
- **Offizielle „Connect-Verzeichnisse"** listen je Marktpartner Endpunkt-Adressen und unterstützte Version — auswertbare Liste, welcher Großhändler was kann

Quelle: [itek.de](https://itek.de/wissen/verzeichnis-branchenstandards/ids-connect)

### GAEB DA XML (Konfidenz: hoch)

- **Version 3.3, Stand 2023-01.** Einzige inhaltliche Änderung gegenüber der Vorversion: Phase **X31 Mengenermittlung** erlaubt jetzt **eingebettete Anlagen (Bilder, PDF) in Base64** → standardkonforme Kopplung von mobiler Baustellendoku und VOB-Aufmaß
- **Ausgabestände unterscheiden sich je Paket:** nur Mengenermittlung ist auf 2023-01; Leistungsverzeichnis, Handel, Kosten/Kalkulation, Rechnung und Zeitvertrag stehen auf **2021-05**. Implementierung muss **pro Paket** prüfen, nicht pro Gesamtversion
- **Preisspiegel (X84P) und Raumbuch (X61)** existieren nicht als freigegebene 3.3-Dateien — nur Beta 3.2-3 von **2013-09**. Für ein MVP nicht anschlussfähig
- **pyGAEB unterstützt GAEB 90 (fixed-width, klassische D81/D83/D84) NICHT** — nur „Planned". Für vor-XML-Dateien braucht es eine separate Lösung
- pyGAEB bringt Cross-Phase-Prüfungen mit, die zentrale Domäneninvarianten erzwingen: X83→X84 strukturelle Identität, X86→X89 Einheitspreis-Abgleich, X86→X88 Nachtrags-Rückverfolgbarkeit

Quelle: [gaeb.de](https://www.gaeb.de/de/produkte/gaeb-datenaustausch/versionen/gaeb-da-xml-version-3-3-stand-2023-01/)

> **DATANORM und UGL sind vollständig unbelegt.** Verifiziert ist nur, *dass*
> plancraft DATANORM ab dem Pro-Tarif anbietet — nicht Spezifikation, Version,
> Bezugsquelle oder Lizenzbedingungen.

---

## 5. Free-Tier-Grenzen (Stand August 2026, USD netto)

### Cloudflare R2 — konkurrenzlos für Fotos (Konfidenz: hoch)

| | Free | Standard |
|---|---|---|
| Speicher | 10 GB-month | $0,015 / GB-Monat |
| Class A (schreibend, z. B. Upload) | 1 Mio. Requests/Monat | $4,50 / Mio. |
| Class B (lesend) | 10 Mio. Requests/Monat | $0,36 / Mio. |
| **Egress** | **kostenlos** | **kostenlos** |

10 GB ≈ **3.000–10.000 komprimierte Baustellenfotos** (1–3 MB). 500 GB
Baustellendoku kosten **$7,35/Monat**. Infrequent Access ($0,01/GB) ist vom
Free-Tier **ausgenommen**, hat $0,01/GB Retrieval und 30 Tage Mindestspeicherdauer.

### Cloudflare D1 — der Engpass (Konfidenz: hoch für Zahlen, mittel für Bewertung)

| | Free | Paid |
|---|---|---|
| Gelesene Zeilen | 5 Mio./Tag | 25 Mrd./Monat, dann $0,001/Mio. |
| **Geschriebene Zeilen** | **100.000/Tag** | 50 Mio./Monat, dann $1,00/Mio. |
| Speicher | 5 GB | 5 GB, dann $0,75/GB-Monat |

**100.000 Schreibzeilen/Tag ≈ 69/Minute im Mittel.** Für ein transaktionales
CRM/ERP mit Zeiterfassung, Belegpositionen und Doku ist das der harte Engpass.
Verschärfend: D1 zählt **gescannte** Zeilen — ein Full Table Scan über 5.000
Zeilen zählt 5.000 Reads. DDL (`CREATE`/`ALTER`/`DROP`) zählt auf **beide**
Kontingente, relevant bei häufigen Migrationen.

→ **Deshalb Postgres statt D1.**

### Supabase (Konfidenz: hoch)

| | Free | Pro ($25/Monat) |
|---|---|---|
| Pausierung | **nach 1 Woche Inaktivität** | nie |
| Aktive Projekte | **max. 2** | — |
| Backups | **nicht enthalten** | 7 Tage |
| Log-Retention | 1 Tag | 7 Tage |
| Max. Dateigröße | 50 MB | 500 GB |
| File Storage | — | 100 GB inkl., dann $0,0213/GB |
| **Egress** | — | 250 GB inkl., dann **$0,09/GB** (cached $0,03) |
| DB-Disk | — | 8 GB/Projekt, dann $0,125/GB |

Pro enthält $10/Monat Compute-Credits = genau eine Micro-Instanz. Höhere
Stufen kosten extra (Small $15, Medium $60, Large $110 … 16XL $3.730).
Team ab $599/Monat. PITR $100/Monat je 7 Tage Retention.

> **Egress ist ~4× teurer als Storage.** Kostentreiber ist das *Ausliefern* der
> Fotos, nicht deren Speicherung. → Fotos gehören in R2 (0 Egress), Daten in Postgres.

### Vercel Hobby — rechtlich ausgeschlossen (Konfidenz: hoch)

> „Hobby teams are restricted to **non-commercial personal use only**. All
> commercial usage of the platform requires either a Pro or Enterprise plan."

„Kommerziell" ist sehr weit definiert: **jedes Deployment zum finanziellen
Gewinn irgendeiner an der Produktion beteiligten Person**, ausdrücklich auch
eines bezahlten Angestellten oder Beraters, der den Code schreibt. Auch
Zahlungsabwicklung, Produktbewerbung und Spendenaufrufe zählen dazu.
**Ein im Kundenauftrag entwickeltes CRM fällt schon in der Entwicklungsphase darunter.**

Quelle: [Vercel Fair Use Guidelines](https://vercel.com/docs/limits/fair-use-guidelines) (Stand 2026-07-29)

Hobby-Richtwerte (unverbindlich): 100 GB Fast Data Transfer, 4 CPU-Stunden,
1 Mio. Invocations, **5.000 Image Transformations**, 300.000 Cache Reads.
Die 5.000 Bildtransformationen sind für ein fotolastiges Handwerks-CRM ohnehin
ein harter Engpass.

---

## 6. Multi-Tenancy — RLS-Performance (Konfidenz: hoch)

Supabases eigene Benchmarks. **Diese vier Muster sind nicht optional** — ohne
sie kippt die Mandantentrennung in Timeouts.

| Muster | Falsch | Richtig | Messung |
|---|---|---|---|
| **Sub-SELECT-Wrapping** | `auth.uid() = user_id` | `(select auth.uid()) = user_id` | 179 ms → **9 ms** (100k Zeilen) |
| **Join-Richtung** | `auth.uid() in (select user_id from team_user where team_id = table.team_id)` | `team_id in (select team_id from team_user where user_id = auth.uid())` | 9.000 ms → **20 ms** |
| **Rolle in TO-Klausel** | Policy ohne `TO` | `TO authenticated` | 170 ms → **< 0,1 ms** |
| **Client-Filter zusätzlich** | nur RLS | RLS **+** `.eq('user_id', userId)` | 171 ms → **9 ms** |

Auf 1 Mio. Zeilen mit 1.000-Zeilen-Team-Mapping: `team_id = ANY(user_teams())`
läuft **selbst mit Index in einen Timeout > 3 Minuten**. Erst
`team_id = ANY(ARRAY(select user_teams()))` **plus** Index auf `team_id` bringt
es auf ~2 ms — der Index wirkt also **erst, wenn die Funktion gewrappt ist**.

Ab ~10.000 Einträgen in der `IN`-Liste ist zusätzliche Analyse nötig.

Quelle: [Supabase RLS Performance](https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv)

---

## 7. Markt

### Preisanker (Konfidenz: hoch)

**plancraft** (netto, Laufzeit-abhängig):

| Paket | 1 Monat | 12 Monate | 24 Monate | Enthalten |
|---|---|---|---|---|
| Business | 74,90 € | 59,90 € | 47,92 € | 1 Büro-Seat |
| Pro | 139,90 € | 109,90 € | 87,92 € | 2 Büro-Seats, **ab hier GAEB + DATANORM** |
| Premium | 249,90 € | 199,90 € | 159,92 € | 3 Büro-Seats, Plantafel inkl. |

Zusätzliche Büro-Nutzer 39,92–59,90 €/Monat, mobile Lizenzen 15,92–24,90 €/Monat.
**Plantafel** (Einsatzplanung) ist Add-on **ab 40 €/Monat**, nur in Premium inklusive.
Kein Setup-Fee, keine Kündigungsfrist, aber nur **7 Tage Test** und geführtes
Onboarding ausschließlich für Premium.

**hero Software** (Konfidenz: niedrig — Wettbewerber-Quelle): ab 59 €/Monat
für 1 Nutzer + ~22 € je weiterem.

> **Der Preiskorridor, den ein einfacheres Produkt unterbieten muss, liegt bei
> 59–140 €/Monat Grundpreis plus Seat-Aufschläge.** Ein 30-Mann-Betrieb landet
> bei plancraft schnell im dreistelligen Monatsbereich.

### Nutzerkritik (Konfidenz: mittel)

- **Bewertungsbasis ist extrem dünn:** plancraft 32, ToolTime 31, HERO 26, mfr 12 Reviews — gegenüber Housecall Pro 2.743, Jobber 1.475, FieldPulse 490. Wettbewerbsschwächen sind aus Capterra allein **nur schwach belegbar**
- **HERO** 4,4/5 (n=26): Bedienbarkeit 4,6 und Service 4,5 liegen **über** Funktionen 4,2 und Preis-Leistung 4,2 → Druck liegt bei Funktionsabdeckung und Preis, nicht bei UI-Politur
- **HERO-Funktionslücke:** „Subunternehmen kann ich nicht direkt einplanen" → **Fremdleistung/Subunternehmer von Anfang an als planbare Ressource modellieren**, nicht nur als Kostenart
- **openHandwerk** 4,2/5 (n=5): Bedienkomfort ist die **schwächste** Dimension. Selbst eine 5-Sterne-Bewertung nennt „man muss das Programm auch lernen und verstehen"
- Negative openHandwerk-Bewertung nennt Basisdefizite als Mindestanforderung an ein mobiles Tool: **Nutzung auf unterschiedlichen Geräten, Zuverlässigkeit, Copy-and-Paste**

### Nachfrage (Bitkom-Studie 01/2026, Konfidenz: hoch)

Digitale Kundenservices: Angebotsversand **68 %**, Rechnungsversand **62 %**,
Online-Terminbuchung 48 %, Online-Beratung 35 %, **digitale Dokumentation von
Arbeitsschritten erst 29 %**, Online-Zahlung 27 %.

→ **Baustellendokumentation ist ein schwach besetztes Feld.** Angebot und
Rechnung sind Tafelstandard und müssen einfach nur gut sein.

---

## 8. Feld-UX und KI

### Das eigentliche Hindernis ist Orientierungslosigkeit (Konfidenz: hoch)

- **58 %** wissen nach eigener Aussage **nicht, was technisch möglich ist**
- Cloud Computing 56 %, Trackingsysteme 20 %, „smarte Software" 17 %, 3D 12 %, VR/AR 5 %
- Bei vielen Technologien liegt „kein Thema" **über 50 %**; gegenüber 2022 kaum Bewegung

> **Die Marktlücke liegt bei Erklärbarkeit und Onboarding, nicht beim Funktionsumfang.**

Peer-reviewte Studie (Olugboyega et al., *Construction Innovation* 24(4):912-932,
DOI 10.1108/CI-04-2022-0094): Die **digitalen Eigenschaften der Fachkräfte
erklären mindestens 50 % der Varianz** in der App-Akzeptanz über 34 untersuchte
Apps. Stärkste Prädiktoren: technologische Orientierung (Ladung 0,663),
IT-Kenntnisse (0,649), Smartphone-Nutzung (0,609). Die Autoren weisen selbst
darauf hin, dass **publizierte UX-Forschung speziell für Bau-/Handwerks-Apps
begrenzt** ist.

### KI ist im Handwerk nicht angekommen (Konfidenz: hoch)

**4 %** setzen KI ein, 9 % planen es, **84 % sagen „kein Thema"**. Nur 29 %
sehen Mitarbeitende, die mit KI umgehen können. **41 % erwarten Stellenabbau.**

> **KI darf kein Verkaufsargument im Vordergrund sein — sie muss unsichtbar im
> Arbeitsablauf stecken.**

**Aber plancraft ist bereits da** (Stand 08/2026, ausgeliefertes Produkt, kein Roadmap-Item):
Sprachbedienung als Kernkonzept — sprachgesteuerte **Zeiterfassung** (Tätigkeit
und Zeitraum diktieren, Pausen und witterungsbedingte Ausfälle automatisch),
sprachgesteuertes **Aufmaß** (Maße diktieren, System rechnet, erkennt Einheiten,
schätzt Materialbedarf), **Angebotserzeugung aus Auftragsbeschreibung**.

plancrafts beworbene Zahlen (90 % weniger Schulungsaufwand, < 60 Sekunden
Tagesdoku, 100 % Akzeptanz, 5× genauere Daten) sind **reine Marketingangaben
ohne Methodik** — sie zeigen aber, gegen welche Erwartungshaltung positioniert
werden muss.

### Hemmnisse (Konfidenz: hoch)

Datenschutz/IT-Sicherheit **96 %** · hohe Investitionskosten 69 % · fehlende
Praxisreife 57 % · Zeitmangel 72 % („zu stark ausgelastet") · 59 % halten
Digitalisierung nur für größere Betriebe für wirtschaftlich · 49 % haben
Schwierigkeiten, sie zu bewältigen.

> **Produktstrategie direkt daraus:** einfach, sofort nutzbar, günstig,
> EU-gehostet mit klarer DSGVO-Story.
