# Roadmap

Vier Module wurden für das MVP gewählt. **Das ist viel** — realistisch ist eine
gestaffelte Nutzbarkeit statt eines Big-Bang-Starts. Die Reihenfolge unten
folgt der Bitkom-Nachfrage: Angebot (68 %) und Rechnung (62 %) sind Tafelstandard,
Baustellendokumentation (29 %) ist das schwach besetzte Feld mit
Differenzierungspotenzial.

---

## Phase 0 — Fundament

**Ziel:** Ein Betrieb kann sich anmelden und Kunden anlegen. Nichts weiter.

- Supabase-Projekt in `eu-central-1`, Schema-Migrationen als Code
- **RLS-Policies nach den vier Pflichtmustern** + Testfälle, die Mandantendurchgriff aktiv nachweisen
- Auth, Betriebsanlage, Benutzerverwaltung
- Next.js/OpenNext auf Cloudflare Pages, R2-Bucket, Deployment-Pipeline
- Journal-Trigger und Nummernkreis-Funktion

**Abbruchkriterium:** Wenn ein Testfall Daten eines fremden Betriebs sieht,
geht nichts weiter. Mandantentrennung ist nicht nachrüstbar.

## Phase 1 — Angebot und Rechnung

**Ziel:** Der Betrieb kann Geld verdienen. Ab hier ist die Software nützlich.

- Kunden, Ansprechpartner, Projekte
- Angebotserstellung mit Positionen, Lohn-/Material-/Fremdleistungstrennung
- Angebot → Auftrag → Rechnung als Belegkette
- Festschreibung, Storno, lückenlose Nummernkreise
- PDF-Ausgabe (Visualisierung aus denselben Daten wie das XML)
- **ZUGFeRD 2.0.1 BASIC** erzeugen und versenden
- Mahnstufen und Zahlungseingang

**Nicht in Phase 1:** Validierung der E-Rechnung, Eingangsrechnungen, DATEV-Export.

## Phase 2 — Baustelle

**Ziel:** Der Monteur nutzt es freiwillig. Das ist die eigentliche Hürde.

- PWA-Installation, Offline-Write-Queue mit sichtbarem Status
- Fotodokumentation mit clientseitiger Komprimierung → R2
- Notizen, Sprachnotizen
- Zeiterfassung mobil, Stundenzettel als Rechnungsgrundlage
- Disposition: Kolonnen, Wochenansicht, **Subunternehmer als planbare Ressource**
- Aufmaß mit Formelfeldern

**Abbruchkriterium:** Wenn ein Monteur die Tagesdoku nicht in unter zwei
Minuten schafft, ist das Modul nicht fertig — unabhängig vom Funktionsumfang.

## Phase 3 — Anschlussfähigkeit

**Ziel:** Der Steuerberater und der Großhandel sind angebunden. Ab hier ist
ein Wechsel vom Altsystem zumutbar.

- 💰 **Java-Sidecar**: KoSIT-Validator + Mustangproject, Validierungsbericht archivieren
- **E-Rechnungs-Eingangsseite** — rechtlich seit 01.01.2025 überfällig
- DATEV-Export (Buchungsstapel), vorher gegen das Prüfprogramm 2.2.3.0 getestet
- Materialstamm, Lieferanten, **IDS Connect 2.5** (abwärtskompatibel zu 2.0/2.3)
- GAEB DA XML über pyGAEB — Import X83, Export X84

## Phase 4 — Automatisierung

**Ziel:** Das, was die Konkurrenz schon hat, aber unsichtbar.

- Angebotserzeugung aus Auftragsbeschreibung
- OCR für Lieferscheine und Eingangsrechnungen
- Sprachgesteuerte Zeiterfassung und Aufmaß
- Automatischer Mahnlauf, Wiedervorlagen
- Semantische Artikelsuche über pgvector

> **KI ist kein Verkaufsargument.** 84 % der Betriebe sagen „kein Thema", 41 %
> erwarten Stellenabbau. Die Funktionen müssen im Arbeitsablauf verschwinden,
> nicht auf der Startseite beworben werden.
>
> plancraft liefert Sprachbedienung für Zeiterfassung, Aufmaß und
> Angebotserzeugung **bereits aus**. Das ist kein Differenzierungsmerkmal mehr,
> sondern Gleichstand-Anforderung.

---

## Positionierung

Aus der Marktanalyse ergibt sich die Lücke **nicht** beim Funktionsumfang:

| Beleg | Konsequenz |
|---|---|
| 58 % wissen nicht, was technisch möglich ist | Erklärbarkeit schlägt Funktionsvielfalt |
| openHandwerk: Bedienkomfort ist die schwächste Dimension | Bedienbarkeit ist der angreifbare Punkt |
| HERO: Bedienbarkeit 4,6 > Funktionen 4,2 | Wettbewerbsdruck liegt bei Abdeckung und Preis |
| plancraft nur 7 Tage Test, Onboarding nur für Premium | Onboarding ist frei angreifbar |
| Preisanker 59–140 €/Monat + Seats | Preislich klar unterbietbar |
| 96 % nennen Datenschutz als Hemmnis | EU-Hosting ist Verkaufsargument, kein Detail |

**These:** Gewinnen lässt sich über *sofortige Nutzbarkeit ohne Schulung*,
*ehrliche Preisgestaltung ohne Seat-Fallen* und *EU-Hosting* — nicht über
mehr Funktionen.

> Die Bewertungsbasis ist dünn (plancraft 32, HERO 26, openHandwerk 5 Reviews).
> Diese Positionierung stützt sich auf schwache Evidenz und gehört vor größerem
> Investment durch echte Kundengespräche validiert.
