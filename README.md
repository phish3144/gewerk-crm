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
| [docs/usp.md](docs/usp.md) | Wo der echte Mehrwert liegt — Marktlücke, vier Funktionen, Reihenfolge |
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

## Phase 0 — Stand

| | Zustand |
|---|---|
| Design-Tokens (`app/tokens.css`) | 13 Rollen, Tag und Nacht, 21 Kontrastpaare nachgerechnet |
| Entwürfe (`design/`) | 9 Ansichten als Artboards |
| Schema (`supabase/migrations/`) | 18 Migrationen, 20 Tabellen, gegen echten Postgres ausgeführt |
| Tests (`supabase/tests/`) | 9 Dateien, alle grün |
| Mandantentrennung | 7 Durchgriffsversuche und 12 Wege über die Mandantengrenze abgewehrt |
| GoBD | Festschreibung, Unveränderbarkeit, lückenlose Nummern, anfügendes Journal |
| Rechnungsmodell | Abschlag/Teil/Schluss, Absetzung nach § 14 Abs. 5 UStG, Einbehalt, Skonto, § 13b |
| Rechtevergabe | `anon` entrechtet, kein TRUNCATE, Funktionsfreigabe ausgeschrieben |
| Supabase-Projekt | `gewerk-crm`, Region `eu-central-1`, Postgres 17.6 |
| Schema auf Supabase | 18 Migrationen angewendet, 5 beabsichtigte Linter-Hinweise |

**Anwendungscode gibt es noch nicht.** Das Fundament trägt die Regeln, nicht die
Bedienung: es gibt keine Oberfläche, keine Anmeldung, keinen PDF- oder
E-Rechnungs-Export. Was dafür zu bauen ist, steht in
[docs/roadmap.md](docs/roadmap.md).

```bash
./scripts/db-test.sh     # Datenbank neu bauen, Migrationen, Tests, Kontrastwerte
```

Der Testlauf braucht einen lokalen Postgres. `supabase/local/00_shim.sql` bildet
nach, was Supabase mitbringt (auth-Schema, `auth.uid()`, die Rollen `anon`,
`authenticated`, `service_role` **und deren Standardrechte**) — diese Datei wird
**nie** auf ein Supabase-Projekt angewendet.

Die Standardrechte sind kein Detail: Supabase erteilt neuen Tabellen und
Funktionen automatisch Rechte für `anon` und `authenticated`. Solange der lokale
Cluster das nicht nachbildete, war er strenger als die Produktion — und eine
Zusicherung, die seit `0009` grün war, war es nur deshalb. Siehe
[docs/schema-befunde.md](docs/schema-befunde.md), Nachtrag.

### Sicherheitsprüfung

Supabases eigener Datenbank-Linter läuft zusätzlich zu den Tests, weil er Dinge
sieht, die lokal nicht auffallen — etwa welche Funktionen über die
REST-Schnittstelle erreichbar sind. `0007_haertung.sql` und `0017_rechtevergabe.sql`
haben seine Funde abgearbeitet, von 14 Sicherheitshinweisen auf 5.

Die verbleibenden 5 sind **beabsichtigt**: fünf `security definer`-Funktionen
bleiben für `authenticated` aufrufbar, weil die Anwendung sie braucht. Jede
prüft die Zugehörigkeit selbst gegen `auth.uid()` — `meine_betriebe*()` liefert
nur die eigenen Betriebe des Aufrufers, `beleg_festschreiben()` und
`betrieb_loeschen()` weisen fremde Mandanten ab.

Der Linter ist dabei nicht die letzte Instanz. Zwei der drei Funde in `0017`
standen in keiner Lint-Meldung, und bei der Indexdeckung meldete er 20 von 23
Fällen — Teilindizes zählt er als Deckung, eine Fremdschlüsselprüfung kann sie
aber nicht nutzen.

### Verbindungsdaten

Projekt-Ref und Schlüssel gehören in `.env.local`, nicht ins Repository:

```
NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

Der `service_role`-Schlüssel wird **nie** an den Client ausgeliefert und ist im
Anwendungscode nicht vorgesehen — die Mandantentrennung hängt daran, dass alle
Zugriffe über die Rolle `authenticated` und damit durch RLS laufen.
