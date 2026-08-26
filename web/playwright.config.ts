import { defineConfig, devices } from "@playwright/test";
import { existsSync } from "node:fs";

const VORHANDENER_BROWSER = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  fullyParallel: false,
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
