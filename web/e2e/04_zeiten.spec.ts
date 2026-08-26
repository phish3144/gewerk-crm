import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());
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
test.beforeEach(() => test.skip(!bereit, grund));

async function anmelden(page: Page) {
  await page.goto("/anmelden");
  await page.getByLabel("E-Mail").fill(KONTEN.a.email);
  await page.getByLabel("Passwort").fill(KONTEN.a.passwort);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await expect(page).toHaveURL(/\/uebersicht/);
}

// Baustelle mit festgeschriebenem Auftrag, damit es Positionen zu waehlen gibt.
async function baustelleMitAuftrag(page: Page, marke: string) {
  await page.goto("/kunden/neu");
  await page.getByLabel("Name").fill(`Zeitkunde ${marke}`);
  await page.getByRole("button", { name: "Kunde anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Zeitkunde ${marke}` })).toBeVisible();

  await page.goto("/projekte/neu");
  await page.getByLabel("Bezeichnung").fill(`Zeitbaustelle ${marke}`);
  await page.getByLabel("Kunde").selectOption({ label: `Zeitkunde ${marke}` });
  await page.getByLabel("Status").selectOption("laufend");
  await page.getByRole("button", { name: "Projekt anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Zeitbaustelle ${marke}` })).toBeVisible();

  await page.goto("/belege/neu");
  await page.getByLabel("Kunde").selectOption({ label: `Zeitkunde ${marke}` });
  await page.getByLabel("Projekt").selectOption({ label: `Zeitbaustelle ${marke}` });
  await page.getByRole("button", { name: "Weiter zu den Positionen" }).click();

  await page.getByRole("button", { name: "+ Leistung" }).click();
  await page.getByLabel("Bezeichnung der Position 1").fill("Rohinstallation");
  await page.getByLabel("Menge der Position 1").fill("10");
  await page.getByLabel("Einzelpreis der Position 1").fill("60");
  await page.locator("h1").click();
  await expect(page.locator("[data-speicherstand]")).toHaveAttribute("data-speicherstand", "fertig");

  await page.getByRole("button", { name: "Festschreiben" }).click();
  await expect(page.getByRole("heading", { name: /^AN-/ })).toBeVisible();
  await page.getByRole("button", { name: "Auftrag daraus machen" }).click();
  await expect(page.getByRole("heading", { name: /Auftrag \(Entwurf\)/ })).toBeVisible();
  await page.getByRole("button", { name: "Festschreiben" }).click();
  await expect(page.getByRole("heading", { name: /^AU-/ })).toBeVisible();
}

test("„Keine passende Position\" steht gleichwertig neben den Positionen", async ({ page }) => {
  await anmelden(page);
  await baustelleMitAuftrag(page, LAUF);

  await page.goto("/zeit");
  await page.getByLabel("Baustelle").selectOption({ label: `Zeitbaustelle ${LAUF}` });

  const position = page.getByRole("button", { name: /Rohinstallation/ });
  const ungeklaert = page.getByRole("button", { name: /Keine passende Position/ });

  await expect(position).toBeVisible();
  await expect(ungeklaert).toBeVisible();

  // Gleich gross: waere der Ausweg kleiner, waehlten die Monteure irgendeine
  // Position und der Waechter bekaeme nichts zu sehen.
  const a = await position.boundingBox();
  const b = await ungeklaert.boundingBox();
  expect(a && b).toBeTruthy();
  expect(Math.abs((a!.width) - (b!.width))).toBeLessThan(2);
  expect(b!.height).toBeGreaterThanOrEqual(a!.height);
  // Und mit Handschuhen zu treffen.
  expect(b!.height).toBeGreaterThanOrEqual(60);
});

test("erfasste Zeit landet in der Datenbank, auch ohne Position", async ({ page }) => {
  await anmelden(page);
  await page.goto("/zeit");
  await page.getByLabel("Baustelle").selectOption({ label: `Zeitbaustelle ${LAUF}` });

  await page.getByRole("button", { name: /Keine passende Position/ }).click();
  await expect(page.getByRole("heading", { name: /^Läuft seit/ })).toBeVisible();
  await page.getByLabel("Was wurde gemacht?").fill(`Ungeklärte Arbeit ${LAUF}`);
  await page.getByRole("button", { name: "Stopp" }).click();

  await expect(page.getByText(`Ungeklärte Arbeit ${LAUF}`)).toBeVisible();
  await expect(page.getByText("noch nicht zugeordnet").first()).toBeVisible();
});

test("ohne Netz erfasst, mit Netz uebertragen — und nur einmal", async ({ page, context }) => {
  await anmelden(page);
  await page.goto("/zeit");
  await page.getByLabel("Baustelle").selectOption({ label: `Zeitbaustelle ${LAUF}` });

  await context.setOffline(true);

  await page.getByRole("button", { name: /Rohinstallation/ }).click();
  await page.getByLabel("Was wurde gemacht?").fill(`Offline erfasst ${LAUF}`);
  await page.getByRole("button", { name: "Stopp" }).click();

  // Der Zustand wird angezeigt, nicht verschwiegen.
  const anzeige = page.locator("[data-warteschlange]");
  await expect(anzeige).toContainText("wartet");

  await context.setOffline(false);
  await page.evaluate(() => window.dispatchEvent(new Event("online")));

  await expect(anzeige).toHaveCount(0, { timeout: 15000 });

  // Genau ein Datensatz, nicht zwei: die Kennung kommt vom Geraet.
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  const { data } = await supabase
    .from("zeiteintrag")
    .select("id, taetigkeit")
    .eq("taetigkeit", `Offline erfasst ${LAUF}`);
  expect(data?.length, "genau ein Eintrag").toBe(1);
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  await supabase.from("zeiteintrag").delete().ilike("taetigkeit", `%${LAUF}%`);
});
