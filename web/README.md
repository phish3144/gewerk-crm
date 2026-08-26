# web — die Anwendung

Next.js (App Router) als PWA, ausgerollt über OpenNext auf Cloudflare.

```bash
npm install
cp .env.example .env.local   # Werte eintragen
npm run dev                  # Entwicklung
npm run pruefen              # Typen, Build, Dienstschlüssel-Prüfung
npm run e2e                  # Oberflächentests
```

## Was wo liegt

| | |
|---|---|
| `app/` | Seiten und Server Actions |
| `app/stile/` | **erzeugt** — Kopien von `app/tokens.css` und `app/basis.css` aus dem Wurzelverzeichnis |
| `lib/supabase/` | Klienten für Browser und Server |
| `lib/betrieb.ts` | Zugehörigkeit und aktiver Mandant |
| `komponenten/` | Wiederverwendbare Bausteine |
| `e2e/` | Oberflächentests mit Playwright |

## Zwei Regeln, die nicht verhandelbar sind

**Kein Dienstschlüssel im Browser.** Die gesamte Mandantentrennung hängt daran,
dass jeder Zugriff als Rolle `authenticated` läuft und damit durch RLS. Ein
`service_role`-Schlüssel im Bundle hebelt das vollständig aus — und zwar
unbemerkt, weil die Anwendung damit *besser* funktioniert, nicht schlechter.
`scripts/kein-dienstschluessel.mjs` prüft das nach jedem Build.

**Die Datenbank rechnet, der Client zeigt.** Summen, Nummern und Fristen kommen
aus Postgres. Weicht der Client ab, ist der Client falsch.

## Die Tokens haben eine Quelle

`app/tokens.css` und `app/basis.css` im **Wurzelverzeichnis** sind die Quelle;
dort prüft `scripts/kontrast.mjs` die Kontraste und dort baut
`scripts/vorschau-bauen.mjs` die Entwurfsvorschau. `scripts/stile-holen.mjs`
kopiert sie vor jedem Lauf nach `web/app/stile/`, damit der Bundler nicht über
die Projektgrenze greifen muss. **Änderungen gehören in die Quelle**, nie in die
Kopie.

## Der Browser für die Tests

In der Entwicklungsumgebung liegt Chromium bereits unter `/opt/pw-browsers`.
`playwright.config.ts` verweist darauf, wenn die Datei existiert, und fällt sonst
auf den Standardweg zurück. `npx playwright install` ist dort nicht nötig.

## Ausrollen

```bash
export CLOUDFLARE_API_TOKEN=<token>   # Vorlage "Edit Cloudflare Workers"
npm run cf:build
npx wrangler deploy
```

Es entsteht **ein** Worker (`gewerk-crm`) mit der `ASSETS`-Bindung für die
statischen Dateien und der R2-Bindung `DOKUMENTE`. Nach dem Deploy nennt wrangler
die aufgelösten Bindungen — dort muss `gewerk-crm-storage (eu)` stehen, sonst
zeigt die Bindung auf den falschen oder gar keinen Bucket.

## Grenze der Oberflächentests in dieser Umgebung

`npm run e2e` läuft gegen den lokalen Server. Gegen eine **öffentliche Adresse**
laufen die Tests hier nicht: der Browser aus `/opt/pw-browsers` kommt nicht durch
den Agent-Proxy und bricht mit `ERR_CONNECTION_RESET` ab, während `curl` durchgeht.
Die ausgerollte Fassung wird deshalb mit `curl` und `wrangler tail` geprüft —
ausgeliefertes HTML, Stylesheet, Schriften, Bundle-Inhalt und Laufzeitfehler.
Auf einem Rechner ohne diesen Proxy funktionieren die Tests auch gegen die
Live-Adresse.
