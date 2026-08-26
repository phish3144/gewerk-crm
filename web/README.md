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
