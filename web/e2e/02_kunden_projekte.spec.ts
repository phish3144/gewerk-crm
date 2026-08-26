import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

// Die Pruefkonten entstehen hier und nicht in einem globalSetup: schlaegt ihre
// Einrichtung fehl, sollen nur die Tests ausfallen, die eine Anmeldung
// brauchen — und mit der Ursache im Klartext, statt dass der ganze Lauf steht.
let bereit = true;
let grund = "";

test.beforeAll(async () => {
  try {
    for (const konto of Object.values(KONTEN)) await kontoBereitstellen(konto);
  } catch (fehler) {
    bereit = false;
    grund = fehler instanceof Error ? fehler.message : String(fehler);
    console.warn("\nPruefkonten nicht verfuegbar:\n" + grund + "\n");
  }
});

test.beforeEach(() => {
  test.skip(!bereit, grund);
});

// Jeder Lauf arbeitet mit eigenen Namen, damit wiederholte Laeufe sich nicht
// gegenseitig sehen. Die Zeit kommt aus dem Prozess, nicht aus der Datenbank.
const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());

// Next haengt fuer Routenansagen ein eigenes role="alert" in jede Seite. Ein
// pauschales getByRole("alert") trifft deshalb zwei Elemente. Diese beiden
// Helfer zielen genau auf unsere eigenen Meldungen — und pruefen dabei mehr als
// vorher: dass der Fehler ueber aria-describedby wirklich am Feld haengt und
// das Feld als fehlerhaft ausgezeichnet ist. Ein Fehler, der nur danebensteht,
// erreicht niemanden, der die Seite vorlesen laesst.
async function feldFehler(page: Page, feld: string) {
  const eingabe = page.locator(`#${feld}`);
  await expect(eingabe).toHaveAttribute("aria-invalid", "true");
  await expect(eingabe).toHaveAttribute("aria-describedby", new RegExp(`${feld}-fehler`));
  return page.locator(`#${feld}-fehler`);
}

function meldung(page: Page) {
  return page.locator(".hinweis[role='alert']");
}

async function anmelden(page: Page, konto: (typeof KONTEN)[keyof typeof KONTEN]) {
  await page.goto("/anmelden");
  await page.getByLabel("E-Mail").fill(konto.email);
  await page.getByLabel("Passwort").fill(konto.passwort);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await expect(page).toHaveURL(/\/uebersicht/);
}

test.describe("Kunden", () => {
  test("anlegen, finden, aendern", async ({ page }) => {
    await anmelden(page, KONTEN.a);

    const name = `Dachdecker ${LAUF}`;
    await page.goto("/kunden/neu");
    await page.getByLabel("Name").fill(name);
    await page.getByLabel("Kundennummer").fill(`K-${LAUF}`);
    await page.getByLabel("Ort").fill("Musterstadt");
    await page.getByRole("button", { name: "Kunde anlegen" }).click();

    // Nach dem Anlegen steht die Detailseite mit dem Namen als Titel.
    await expect(page.getByRole("heading", { name })).toBeVisible();

    // Die Suche findet ihn.
    await page.goto("/kunden");
    await page.getByRole("searchbox", { name: "Kunden durchsuchen" }).fill(String(LAUF));
    await page.getByRole("button", { name: "Suchen" }).click();
    await expect(page.getByRole("link", { name: new RegExp(name) })).toBeVisible();

    // Aendern wirkt und wird bestaetigt.
    await page.getByRole("link", { name: new RegExp(name) }).click();
    await page.getByLabel("Ort").fill("Neustadt");
    await page.getByRole("button", { name: "Änderungen speichern" }).click();
    await expect(page.getByRole("status")).toContainText("Gespeichert");
    await expect(page.getByLabel("Ort")).toHaveValue("Neustadt");
  });

  test("doppelte Kundennummer wird am Feld gemeldet, nicht als SQL-Text", async ({ page }) => {
    await anmelden(page, KONTEN.a);
    const nummer = `DOPPELT-${LAUF}`;

    for (const durchgang of [1, 2]) {
      await page.goto("/kunden/neu");
      await page.getByLabel("Name").fill(`Zweitkunde ${durchgang} ${LAUF}`);
      await page.getByLabel("Kundennummer").fill(nummer);
      await page.getByRole("button", { name: "Kunde anlegen" }).click();

      if (durchgang === 2) {
        const fehler = await feldFehler(page, "nummer");
        await expect(fehler).toContainText("Kundennummer");
        // Kein Datenbankjargon in der Oberflaeche.
        await expect(fehler).not.toContainText(/constraint|duplicate|violates|key/i);
      }
    }
  });

  test("Skonto ueber 100 Prozent wird am Feld abgewiesen", async ({ page }) => {
    await anmelden(page, KONTEN.a);
    await page.goto("/kunden/neu");
    await page.getByLabel("Name").fill(`Skontokunde ${LAUF}`);
    // Die Browser-Pruefung umgehen, damit die Server-Regel wirklich laeuft.
    await page.getByLabel("Skonto", { exact: true }).evaluate((el: HTMLInputElement) => {
      el.removeAttribute("max");
      el.value = "150";
    });
    await page.getByRole("button", { name: "Kunde anlegen" }).click();
    const fehler = await feldFehler(page, "skonto_prozent");
    await expect(fehler).toContainText("zwischen 0 und unter 100");
  });
});

test.describe("Projekte", () => {
  test("brauchen einen Kunden und lassen sich anlegen", async ({ page }) => {
    await anmelden(page, KONTEN.a);

    const kunde = `Projektkunde ${LAUF}`;
    await page.goto("/kunden/neu");
    await page.getByLabel("Name").fill(kunde);
    await page.getByRole("button", { name: "Kunde anlegen" }).click();
    await expect(page.getByRole("heading", { name: kunde })).toBeVisible();

    const bezeichnung = `Baustelle ${LAUF}`;
    await page.goto("/projekte/neu");
    await page.getByLabel("Bezeichnung").fill(bezeichnung);
    await page.getByLabel("Kunde").selectOption({ label: kunde });
    await page.getByLabel("Status").selectOption("laufend");
    await page.getByRole("button", { name: "Projekt anlegen" }).click();

    await expect(page.getByRole("heading", { name: bezeichnung })).toBeVisible();
    await page.goto("/projekte");
    await expect(page.getByRole("link", { name: new RegExp(bezeichnung) })).toBeVisible();
  });

  test("Ende vor Beginn wird am Feld abgewiesen", async ({ page }) => {
    await anmelden(page, KONTEN.a);
    await page.goto("/projekte/neu");
    await page.getByLabel("Bezeichnung").fill(`Zeitraum ${LAUF}`);
    await page.getByLabel("Kunde").selectOption({ index: 1 });
    await page.getByLabel("Beginn").fill("2026-09-01");
    await page.getByLabel("Ende").fill("2026-08-01");
    await page.getByRole("button", { name: "Projekt anlegen" }).click();
    const fehler = await feldFehler(page, "ende");
    await expect(fehler).toContainText("nicht vor dem Beginn");
  });
});

test.describe("Mandantentrennung durch die Oberflaeche", () => {
  test("fremder Kunde ist ueber die Adresse nicht erreichbar", async ({ page }) => {
    // A legt an und merkt sich die Adresse.
    await anmelden(page, KONTEN.a);
    const name = `Geheimkunde ${LAUF}`;
    await page.goto("/kunden/neu");
    await page.getByLabel("Name").fill(name);
    await page.getByRole("button", { name: "Kunde anlegen" }).click();
    await expect(page.getByRole("heading", { name })).toBeVisible();
    const adresse = new URL(page.url()).pathname;

    // Abmelden ueber den Knopf in der Kopfzeile, also den Weg, den auch eine
    // Nutzerin nimmt. Ein GET auf /abmelden waere kein gueltiger Weg: die Route
    // beantwortet absichtlich nur POST, damit sie sich nicht von fremder Seite
    // aus ausloesen laesst.
    await page.getByRole("button", { name: "Abmelden" }).click();
    await page.waitForURL(/\/anmelden/);

    await anmelden(page, KONTEN.b);
    const antwort = await page.goto(adresse);

    expect(antwort?.status(), "Fremder Kunde muss 404 liefern").toBe(404);
    await expect(page.locator("body")).not.toContainText(name);
  });

  test("B sieht die Kunden von A nicht in der Liste", async ({ page }) => {
    await anmelden(page, KONTEN.b);
    await page.goto("/kunden");
    await expect(page.locator("body")).not.toContainText(String(LAUF));
  });
});

test.afterAll(async () => {
  if (!bereit) return;
  // Aufraeumen ueber die Anwendungsrolle, nicht mit erhoehten Rechten: was der
  // Test angelegt hat, muss er auch wieder loeschen koennen.
  const supabase = klient();
  await supabase.auth.signInWithPassword({
    email: KONTEN.a.email,
    password: KONTEN.a.passwort,
  });
  await supabase.from("projekt").delete().ilike("bezeichnung", `%${LAUF}%`);
  await supabase.from("kunde").delete().ilike("name", `%${LAUF}%`);
});
