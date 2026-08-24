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

## Phase 0 — Stand

| | Zustand |
|---|---|
| Design-Tokens (`app/tokens.css`) | 13 Rollen, Tag und Nacht, 21 Kontrastpaare nachgerechnet |
| Schema (`supabase/migrations/`) | 6 Migrationen, gegen echten Postgres ausgeführt |
| Mandantentrennung | 7 Durchgriffsversuche werden abgewehrt |
| GoBD | Festschreibung, Unveränderbarkeit, lückenlose Nummern, Journal |
| Supabase-Projekt | `gewerk-crm`, Region `eu-central-1`, Postgres 17 |
| Schema auf Supabase | 7 Migrationen angewendet, Linter meldet nur noch einen beabsichtigten Hinweis |

```bash
./scripts/db-test.sh     # Datenbank neu bauen, Migrationen, Tests, Kontrastwerte
```

Der Testlauf braucht einen lokalen Postgres. `supabase/local/00_shim.sql` bildet
nach, was Supabase mitbringt (auth-Schema, `auth.uid()`, die Rollen `anon`,
`authenticated`, `service_role`) — diese Datei wird **nie** auf ein
Supabase-Projekt angewendet.

### Sicherheitsprüfung

Supabases eigener Datenbank-Linter läuft zusätzlich zu den Tests, weil er Dinge
sieht, die lokal nicht auffallen — etwa welche Funktionen über die
REST-Schnittstelle erreichbar sind. Er meldete fünf Punkte, `0007_haertung.sql`
behebt vier davon:

- `btree_gist` lag im Schema `public`, das die API ausliefert → nach `extensions` verschoben
- `journal_schreiben()` war als `security definer` für `anon` und `authenticated`
  über `/rest/v1/rpc/` aufrufbar → Ausführungsrecht vollständig entzogen
- `meine_betriebe()` war für `anon` aufrufbar → entzogen

Der verbleibende Hinweis ist **beabsichtigt**: `meine_betriebe()` muss für
`authenticated` ausführbar bleiben, weil jede RLS-Policy sie aufruft. Ein
Direktaufruf liefert nur die eigenen Betriebe des Aufrufers zurück — also
nichts, was er nicht ohnehin weiß.

### Verbindungsdaten

Projekt-Ref und Schlüssel gehören in `.env.local`, nicht ins Repository:

```
NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

Der `service_role`-Schlüssel wird **nie** an den Client ausgeliefert und ist im
Anwendungscode nicht vorgesehen — die Mandantentrennung hängt daran, dass alle
Zugriffe über die Rolle `authenticated` und damit durch RLS laufen.
