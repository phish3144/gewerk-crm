import { defineConfig, devices } from "@playwright/test";
import { existsSync } from "node:fs";
import { config } from "dotenv";

// Vor allem anderen: die Konfigurationsdatei wird als Erstes ausgewertet.
config({ path: ".env.local", quiet: true });

const VORHANDENER_BROWSER = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  fullyParallel: false,
  // Ein Arbeiter, nicht zwei. Alle angemeldeten Tests benutzen dasselbe
  // Pruefkonto, und Supabase tauscht bei jeder Tokenerneuerung das
  // Refresh-Token aus: erneuert der zweite Browser, wird die Sitzung des ersten
  // ungueltig und er landet mitten im Test auf der Anmeldemaske. Das ist eine
  // Eigenheit des gemeinsamen Kontos, kein Fehler der Anwendung — zwei echte
  // Nutzer haetten getrennte Sitzungen. Der Lauf dauert dadurch etwa doppelt so
  // lange und ist dafuer wiederholbar.
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: "http://127.0.0.1:3100",
    locale: "de-DE",
    timezoneId: "Europe/Berlin",
  },
  projects: [
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        // In dieser Umgebung liegt Chromium fertig unter /opt/pw-browsers. Die
        // Fassung passt nicht zur Versionsnummer, die @playwright/test erwartet,
        // deshalb wird sie ausdruecklich benannt statt nachgeladen. Auf einem
        // Rechner ohne diese Datei greift der Standardweg.
        launchOptions: existsSync(VORHANDENER_BROWSER)
          ? { executablePath: VORHANDENER_BROWSER }
          : {},
      },
    },
  ],
  webServer: {
    command: "npm run start -- --port 3100 --hostname 127.0.0.1",
    url: "http://127.0.0.1:3100/anmelden",
    reuseExistingServer: true,
    timeout: 60_000,
  },
});
