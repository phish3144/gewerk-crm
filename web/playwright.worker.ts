import { defineConfig, devices } from "@playwright/test";
import { existsSync } from "node:fs";
import { config } from "dotenv";
config({ path: ".env.local", quiet: true });

const BROWSER = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";

// Gegen die Worker-Fassung, nicht gegen `next start`. Nur dort gibt es die
// R2-Bindung — in der Node-Fassung faellt sie weg, und der Dateipfad waere
// ungeprueft.
export default defineConfig({
  testDir: "./e2e",
  // Alles, was die R2-Bindung braucht.
  testMatch: /(05_doku|08_bedenken_foto)\.spec\.ts/,
  timeout: 60_000,
  workers: 1,
  reporter: [["list"]],
  use: { baseURL: "http://127.0.0.1:3200", locale: "de-DE" },
  // wrangler dev bedient den bereits gebauten Worker aus .open-next samt
  // R2-Bindung. Vorher muss `npm run cf:build` gelaufen sein.
  webServer: {
    command: "npx wrangler dev --port 3200 --ip 127.0.0.1",
    url: "http://127.0.0.1:3200/anmelden",
    reuseExistingServer: true,
    timeout: 120_000,
  },
  projects: [
    {
      name: "worker",
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: existsSync(BROWSER) ? { executablePath: BROWSER } : {},
      },
    },
  ],
});
