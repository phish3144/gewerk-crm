# gewerk-crm

CRM/ERP für deutsche Handwerksbetriebe mit 10–50 Mitarbeitern.
Modern, einfach bedienbar, stark automatisiert — und rechtssicher nach deutschem Steuerrecht.

## Status

**Planungsphase.** Noch kein Anwendungscode. Dieses Repository enthält aktuell den
recherchebasierten Umsetzungsplan.

| Dokument | Inhalt |
|---|---|
| [docs/recherche.md](docs/recherche.md) | Verifizierte Faktenlage mit Quellen — Grundlage aller Entscheidungen |
| [docs/architektur.md](docs/architektur.md) | Stack-Entscheidung, Kostenmodell, Deployment |
| [docs/datenmodell.md](docs/datenmodell.md) | Schema, RLS-Mandantentrennung, GoBD-Unveränderbarkeit |
| [docs/roadmap.md](docs/roadmap.md) | Phasen, Reihenfolge, Abbruchkriterien |
| [docs/offene-fragen.md](docs/offene-fragen.md) | Was **nicht** belegt ist und vor der Umsetzung geklärt werden muss |

## Methodik

Die Faktenbasis stammt aus zwei adversarial verifizierten Recherchelaufen
(420 Agenten, 25 Quellen, 129 extrahierte Behauptungen). Jede Behauptung
wurde von drei unabhängigen Prüfern angegriffen; zwei Widerlegungen genügten
zum Verwerfen. **37 von 129 Behauptungen sind durchgefallen** und stehen
bewusst nicht in diesem Plan — sie sind in `docs/offene-fragen.md` als
ungeklärt vermerkt.

Konfidenzstufen in den Dokumenten:

- **hoch** — Primärquelle (Gesetzestext, BMF-Schreiben, Herstellerdokumentation), einstimmiges Prüfvotum
- **mittel** — Sekundärquelle oder geteiltes Votum (2:1)
- **niedrig** — Einzelquelle oder Blog-Qualität; nicht als Entscheidungsgrundlage verwenden

## Entscheidungen (Stand 2026-08-24)

| Frage | Entscheidung |
|---|---|
| Zielgruppe | 10–50 Mitarbeiter, gewerkübergreifend, mit Baustellen-/Kolonnenplanung |
| MVP-Umfang | Kunden/Angebot/Rechnung · Aufträge/Baustellendoku · Termine/Zeiterfassung · Material/Lieferanten |
| Hosting | Cloudflare Workers + Pages |
| Datenbank | Supabase Postgres (EU, `eu-central-1`) |
| Dateien | Cloudflare R2 |
| Offline | Write-Queue, Server ist Autorität |
| E-Rechnung | Erzeugung + Versand ab MVP; **Validierung vertagt** (kein Java-Sidecar) |
| Compliance | E-Rechnung, GoBD, DATEV-Export |
| Budget | Prototyp auf Free-Tiers; jede Kostenschwelle ist im Plan markiert |
