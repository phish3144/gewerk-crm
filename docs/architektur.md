# Architektur

Alle Entscheidungen leiten sich aus [recherche.md](recherche.md) ab.
Kostenschwellen sind mit 💰 markiert.

---

## Entscheidung

```
                    ┌─────────────────────────────────┐
   Baustelle        │  PWA (Next.js, OpenNext)        │        Büro
   Handy/Tablet ───▶│  Cloudflare Pages + Workers     │◀─── Desktop
                    └────────────┬────────────────────┘
                                 │
                  ┌──────────────┼──────────────┐
                  ▼              ▼              ▼
         ┌────────────────┐ ┌─────────┐ ┌──────────────┐
         │ Supabase       │ │ R2      │ │ Worker-Jobs  │
         │ Postgres 17    │ │ Fotos   │ │ Cron/Queues  │
         │ eu-central-1   │ │ PDFs    │ │ Mahnlauf     │
         │ Auth + RLS     │ │ 0 Egress│ │ E-Rechnung   │
         └────────────────┘ └─────────┘ └──────────────┘
```

| Baustein | Wahl | Begründung |
|---|---|---|
| Frontend | Next.js App Router als **PWA** | Ein Codebase für Büro-Desktop und Baustellen-Handy |
| Hosting | **Cloudflare Workers** (mit Workers Static Assets) | Vercel Hobby ist für kommerzielle Nutzung **rechtlich ausgeschlossen**; Workers-Free-Tier großzügig; Account bereits verbunden |
| Datenbank | **Supabase Postgres**, `eu-central-1` | D1 scheitert an 100.000 Schreibzeilen/Tag; Postgres + RLS ist der belegte Multi-Tenancy-Pfad; Frankfurt = DSGVO |
| Auth | Supabase Auth | RLS-Integration über `auth.uid()` |
| Dateien | **Cloudflare R2** | **0 Egress** — Supabase-Egress kostet $0,09/GB, ~4× Storage-Preis |
| Offline | **Write-Queue** (IndexedDB), Server ist Autorität | Kein Konfliktmodell nötig, kostet nichts, deckt den Baustellenalltag |
| E-Rechnung | XML-Erzeugung in TypeScript | Validierung vertagt → kein Java-Sidecar im MVP |

### Warum nicht D1

100.000 Schreibzeilen/Tag ≈ 69/Minute. Ein 30-Mann-Betrieb erzeugt allein an
Zeiterfassungseinträgen, Belegpositionen und Doku-Datensätzen ein Vielfaches
davon in Spitzen. Verschärfend: D1 zählt **gescannte** Zeilen, ein fehlender
Index kostet das Kontingent überproportional, und DDL zählt auf beide Kontingente.

> Die konkrete Schreiblast ist **nicht gemessen** — siehe
> [offene-fragen.md](offene-fragen.md). Die Entscheidung gegen D1 stützt sich
> auf die Zahlen, nicht auf ein Lastmodell.

### Warum Fotos nach R2 und nicht in Supabase Storage

| | Supabase Pro | R2 |
|---|---|---|
| Storage | 100 GB inkl., dann $0,0213/GB | 10 GB frei, dann $0,015/GB |
| **Egress** | 250 GB inkl., dann **$0,09/GB** | **kostenlos** |

Baustellenfotos werden häufig wiederholt mobil abgerufen — Egress ist der
Kostentreiber, nicht Storage. Bei R2 ist er strukturell null.

### Stand des Ausrollens

| | |
|---|---|
| Worker | `gewerk-crm` |
| Adresse | https://gewerk-crm.f3x.workers.dev |
| Konto | `d217dfbf7039817de7c3ad5e2deee9ab` |
| Bindungen | `DOKUMENTE` (R2, `gewerk-crm-storage`, `eu`), `ASSETS` |

Ausgerollt wird von Hand aus `web/`:

```bash
export CLOUDFLARE_API_TOKEN=<token>
npm run cf:build && npx wrangler deploy
```

**Migrationen laufen nicht ueber git.** Die Supabase-GitHub-Integration ist
verbunden, „Deploy to production" ist aber ausgeschaltet — Migrationen werden
weiterhin ueber den Supabase-Connector angewendet. Die Dateinamen tragen
trotzdem das Zeitstempelformat, damit ein spaeteres Einschalten der Automatik
sofort greift und nichts doppelt laeuft.

### Ein Worker, nicht Pages

OpenNext uebersetzt die Ausgabe von `next build` in **einen Cloudflare Worker**
plus einem Verzeichnis statischer Dateien, die ueber die `ASSETS`-Bindung
ausgeliefert werden. Cloudflare Pages kommt dabei nicht vor — fuer neue Projekte
empfiehlt Cloudflare inzwischen ausdruecklich Workers statt Pages.

Es entsteht also genau **ein** Worker namens `gewerk-crm`, der sowohl die
Serverteile der Anwendung ausfuehrt als auch die statischen Dateien bedient. Die
R2-Bindung haengt an diesem Worker.

> **Zur Kenntnis, nicht zur sofortigen Umsetzung:** Cloudflare nennt seit
> August 2026 `vinext` den empfohlenen Weg fuer neue Next.js-Anwendungen und
> OpenNext den Pfad fuer bestehende. vinext ist Beta. Wir bleiben bei OpenNext,
> weil es traegt und gebaut ist; ein Wechsel ist spaeter moeglich und sollte
> gegen die Vertraeglichkeitsliste geprueft werden, nicht auf Verdacht erfolgen.

### EU-Jurisdiktion: einmalig und unumkehrbar

R2 kennt zwei verschiedene Dinge, die leicht verwechselt werden:

| | Was es zusichert |
|---|---|
| **Location Hint** (`weur`) | Cloudflare bemüht sich um Platzierung in Westeuropa. Keine Zusicherung. |
| **Jurisdiction** (`eu`) | Die Daten werden in der EU **gespeichert und verarbeitet**. Das ist die Zusicherung, die man einem Kunden nennen kann. |

Für uns gilt **Jurisdiction `eu`**, nicht der Hint. Datenschutz ist eines der
drei Verkaufsargumente, und 96 % der Betriebe nennen ihn als Hemmnis.

> **Die Jurisdiktion lässt sich nach dem Anlegen nicht mehr ändern.** Ein
> versehentlich ohne Jurisdiktion angelegter Bucket ist nur durch Löschen und
> Neuanlegen zu korrigieren.

Der Cloudflare-MCP-Connector kann das **nicht**: sein `r2_bucket_create` kennt
nur einen Namen und keine Jurisdiktion. Ein darüber angelegter Bucket landet
dauerhaft ohne EU-Bindung. Zwei Wege, die es können:

```bash
# Dashboard: R2 → Create bucket → Location → "Specify jurisdiction" → EU
# oder:
wrangler r2 bucket create gewerk-crm-storage -J eu --location weur
```

**Folgen für den Anwendungscode** — beides ist beim ersten Zugriff sonst ein
Rätsel:

- Die Worker-Bindung braucht die Jurisdiktion, nicht nur den Namen:
  ```toml
  [[r2_buckets]]
  binding = "DOKUMENTE"
  bucket_name = "gewerk-crm-storage"
  jurisdiction = "eu"
  ```
- Über die S3-API gilt ein eigener Endpunkt:
  `https://<account_id>.eu.r2.cloudflarestorage.com`. Ein Aufruf gegen den
  normalen Endpunkt findet den Bucket nicht.
- Auch beim Auflisten und in den Metriken taucht er nur mit Jurisdiktionsangabe
  auf (in der Metrik als `eu_gewerk-crm-storage`). Ein leeres Ergebnis ohne
  Jurisdiktionsangabe heißt also nicht, dass der Bucket fehlt.
- Logpush arbeitet nicht mit Buckets, die einer Jurisdiktion zugeordnet sind.
  Für uns ohne Belang, aber gut zu wissen, bevor jemand es versucht.

**Angelegt am 26.08.2026:** `gewerk-crm-storage`, Jurisdiktion EU — und am selben
Tag belegt statt vermutet:

```
wrangler r2 bucket list          ->  (leer)
wrangler r2 bucket list -J eu    ->  gewerk-crm-storage
```

Beim Deploy bestaetigt der Worker die Aufloesung selbst:
`env.DOKUMENTE (gewerk-crm-storage (eu))`.

Der MCP-Connector sieht ihn nicht — `r2_buckets_list` liefert eine leere Liste
und `r2_bucket_get` einen 404 mit „The specified bucket does not exist". Das ist
kein Fehler, sondern die Folge der fehlenden Jurisdiktionsangabe in diesen
Aufrufen. **Ein 404 von dort ist also kein Beleg dafür, dass der Bucket fehlt** —
und umgekehrt kann der Connector seine Existenz auch nicht bestätigen.
Verlässlich prüfbar ist er über das Dashboard, über `wrangler r2 bucket list -J eu`
oder ab Schritt 5 dadurch, dass die Worker-Bindung ihn auflöst.

---

## Offline-Konzept

**Server ist die Autorität.** Kein bidirektionales Sync, keine
Konfliktauflösung, keine Sync-Engine-Kosten.

```
Baustelle ohne Netz          Netz wieder da
──────────────────           ──────────────
Foto aufnehmen        ┐
Zeit erfassen         ├─▶ IndexedDB-Queue ──▶ Upload in Reihenfolge ──▶ Server
Notiz schreiben       ┘         (persistent)        (idempotent)
Aufmaß eintragen
```

**Regeln:**

1. Jeder Queue-Eintrag hat eine **client-generierte UUID** → Uploads sind idempotent, Doppel-Sends sind harmlos
2. Die Queue ist **append-only und persistent** — sie überlebt App-Neustart und Akkutod
3. **Lesen** erfordert Netz oder Cache. Die zuletzt geöffneten Aufträge werden vorgehalten
4. Der Nutzer sieht **immer** den Queue-Status: „3 Fotos warten auf Upload"
5. Fotos werden **vor** dem Queuen clientseitig komprimiert (Zielgröße ~500 KB)

> **Was das nicht kann:** Zwei Monteure, die denselben Datensatz offline
> bearbeiten. Für Zeiterfassung, Fotos und Notizen — die realen Offline-Fälle —
> tritt das nicht auf. Sollte sich das ändern, ist **PowerSync** der belegte
> Migrationspfad (lokales SQLite, Logical Replication, RLS-kompatibel,
> Last-Write-Wins) — 💰 Preismodell wurde nicht recherchiert.

---

## E-Rechnung im MVP

**Erzeugen und versenden ja, validieren später.**

```
Rechnung in Postgres
        │
        ├─▶ ZUGFeRD 2.0.1 BASIC (XML) ──┐
        │                                ├─▶ PDF/A-3 mit eingebettetem XML ─▶ Versand
        └─▶ Visualisierung (HTML→PDF) ──┘
```

- Zielformat **ZUGFeRD ab 2.0.1, Profil BASIC oder höher**. MINIMUM und BASIC-WL sind unzulässig
- XML-Erzeugung in TypeScript, direkt aus dem normalisierten Rechnungsdatensatz
- **Der XML-Teil ist rechtlich führend** — die PDF-Visualisierung wird aus denselben Daten gerendert, damit sie inhaltlich nicht abweichen kann

**Vertagt (Phase 3):**

- 💰 Java-Sidecar mit KoSIT-Validator + Mustangproject (~5–10 €/Monat Container)
- Aufbewahrung des Validierungsberichts
- **Eingangsseite** — XML empfangen, parsen, zuordnen, archivieren

> ⚠️ **Die Empfangspflicht gilt seit 01.01.2025 ohne Übergangsfrist.** Sie ist
> damit der einzige Teil, der rechtlich bereits überfällig ist. Für einen
> Prototyp ohne Echtbetrieb unkritisch — vor dem ersten zahlenden Kunden nicht.

---

## Kostenschwellen

| Schwelle | Was passiert | Kosten |
|---|---|---|
| Entwicklung | Supabase Free + Cloudflare Free + R2 Free | **0 €** |
| 💰 1 Woche keine DB-Aktivität | Supabase-Projekt **pausiert** | Pro: **$25/Monat** |
| 💰 Backups nötig | Free hat **keine** | in Pro enthalten (7 Tage) |
| 💰 > 2 aktive Supabase-Projekte | Free-Limit erreicht | Pro |
| 💰 > 10 GB Fotos | ≈ 3.000–10.000 Fotos | $0,015/GB-Monat |
| 💰 Workers-Limits überschritten | — | **$5/Monat** |
| 💰 E-Rechnungs-Validierung | Java-Container | ~5–10 €/Monat |
| 💰 Point-in-Time-Recovery | — | $100/Monat je 7 Tage |

**Realistischer Produktivbetrieb: ~$30/Monat** (Supabase Pro + Workers Paid).
Gegenüber plancraft Business ab 74,90 €/Monat **pro Betrieb** ist das
vernachlässigbar — die Marge trägt sich ab dem ersten Kunden.

---

## Sicherheit und DSGVO

- **Alles in der EU:** Supabase `eu-central-1` (Frankfurt), Cloudflare mit EU-Jurisdiktion für R2
- **Mandantentrennung ausschließlich über RLS** — jede Tabelle trägt `betrieb_id`
- RLS-Policies **zwingend** nach den vier belegten Mustern (siehe [datenmodell.md](datenmodell.md)) — naive Policies laufen in Timeouts
- Der `service_role`-Key wird **niemals** an den Client ausgeliefert; Worker-Jobs laufen serverseitig
- Fotos in R2 nur über **signierte, kurzlebige URLs** — kein öffentlicher Bucket

> ⚠️ **Nicht recherchiert:** konkrete AV-Vertragspflichten, DPA-Lage bei
> Supabase und Cloudflare, Anforderungen an die Verfahrensdokumentation. Vor
> dem ersten Echtkunden zu klären — 96 % der Betriebe nennen Datenschutz als
> Hemmnis, das ist verkaufsentscheidend.
