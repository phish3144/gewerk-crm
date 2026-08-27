import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

// Die Fotos in der Bedenkenanzeige. Nur gegen die Worker-Fassung: die
// R2-Bindung gibt es allein in der workerd-Laufzeit, und ohne sie hat das
// Schriftstueck zwar Text, aber keine Bilder - was hier gerade der Punkt ist.
const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());

test.setTimeout(120_000);

let bereit = true;
let grund = "";

test.beforeAll(async () => {
  try {
    await kontoBereitstellen(KONTEN.a);
  } catch (f) {
    bereit = false;
    grund = f instanceof Error ? f.message : String(f);
  }
});
test.beforeEach(({}, pruefung) => {
  test.skip(!bereit, grund);
  test.skip(
    pruefung.project.name !== "worker",
    "Dateispeicher nur in der Worker-Fassung — siehe playwright.worker.ts",
  );
});

// Ein sichtbares Bild, kein 1x1-Pixel: pdf-lib skaliert es in den Satzspiegel,
// und ein Bild ohne Flaeche wuerde einen Fehler dabei nicht auffallen lassen.
const PNG = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAABUklEQVR4nOXQN3IDQQwEwNZ9" +
    "ShFfz4ivOkUqGboza4DdiWYQofpjXdf1drmYNcvtcvF5vfb+o1sWmBlh+S6zIiy/x4wIy//D" +
    "bAh3AMyF8BCAeRCeAjAHwksAxkd4C8DYCJsAGBdhMwBjIuwCYDyE3QCMhXAIgHEQDgMwBsIp" +
    "APIjnAYgN0IRAPIiFAMgJ0JRAPIhFAcgF0IVAPIgVAMgB0JVAOIjVAcgNkITAOIiNAMgJkJT" +
    "AOIhNAcgFkIXAOIgdAMgBkJXAPojdAegL0IIAPohhAGgD0IoANojhAOgLUJIANohhAWgDUJo" +
    "AOojhAegLkIKAOohpAGgDkIqAMojpAOgLEJKAMohpAWgDEJqAM4jpAfgHMIQABxHGAaAYwhD" +
    "AbAfYTgA9iEMCcB2hGEB2IYwNADvEYYH4DXCFAA8R5gGgMcIUwFwjzAdAH8RpgTgB+ELpe3C" +
    "v2kZ+6kAAAAASUVORK5CYII=",
  "base64",
);

async function anmelden(page: Page) {
  await page.goto("/anmelden");
  await page.getByLabel("E-Mail").fill(KONTEN.a.email);
  await page.getByLabel("Passwort").fill(KONTEN.a.passwort);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await expect(page).toHaveURL(/\/uebersicht/);
}

test("das Beweisfoto steht in der Bedenkenanzeige", async ({ page }) => {
  const marke = `FOTO-BA-${LAUF}`;
  await anmelden(page);

  await page.goto("/kunden/neu");
  await page.getByLabel("Name").fill(`Bedenkenkunde ${marke}`);
  await page.getByRole("button", { name: "Kunde anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Bedenkenkunde ${marke}` })).toBeVisible();

  await page.goto("/projekte/neu");
  await page.getByLabel("Bezeichnung").fill(`Bedenkenbaustelle ${marke}`);
  await page.getByLabel("Kunde").selectOption({ label: `Bedenkenkunde ${marke}` });
  await page.getByRole("button", { name: "Projekt anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Bedenkenbaustelle ${marke}` })).toBeVisible();
  const pfad = new URL(page.url()).pathname;

  // Ein Foto von der Baustelle - dasselbe, das spaeter den Nachweis traegt.
  await page.goto(`${pfad}/doku`);
  await page.getByLabel("Notiz").fill(`Riss in der Wand ${marke}`);
  await page.locator("input[type=file]").setInputFiles({
    name: "riss.png",
    mimeType: "image/png",
    buffer: PNG,
  });
  // Ueber die Quelle statt ueber den Alternativtext: der traegt die Notiz,
  // sobald eine da ist — was hier gerade der Fall ist.
  await expect(page.locator("img[src^='/api/dokument']").first()).toBeVisible({ timeout: 25000 });

  // Bedenkenanzeige mit genau diesem Nachweis.
  const projektId = pfad.split("/").pop()!;
  await page.goto(`/bedenken/neu?projekt=${projektId}`);
  await page.getByLabel("Betreff").fill(`Untergrund nicht tragfähig ${marke}`);
  await page.getByLabel("Sachverhalt").fill("Der Putzgrund weist Risse auf, die durchschlagen werden.");
  await page.locator("input[name='nachweis']").first().check();
  await page.getByRole("button", { name: "Anzeige anlegen" }).click();
  await expect(page).toHaveURL(/\/bedenken\/[0-9a-f-]{36}/, { timeout: 20000 });
  const anzeigeId = new URL(page.url()).pathname.split("/").pop()!;

  const pdf = await page.request.get(`/api/bedenkenanzeige/${anzeigeId}/pdf`);
  expect(pdf.status()).toBe(200);
  const bytes = await pdf.body();

  // Das eingebettete Bild ist im PDF nachweisbar: pdf-lib legt es als
  // XObject vom Subtype /Image ab. Nur auf die Dateigroesse zu schauen waere
  // kein Nachweis - Text allein macht sie auch groesser.
  const roh = bytes.toString("latin1");
  expect(roh, "ein Bild-XObject im Schriftstueck").toContain("/Subtype /Image");
  expect(bytes.length).toBeGreaterThan(2000);
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  await supabase.from("projekt").delete().ilike("bezeichnung", `%${LAUF}%`);
  await supabase.from("kunde").delete().ilike("name", `%${LAUF}%`);
});
