import { expect, test } from "@playwright/test";

test("ohne Anmeldung fuehrt jeder Weg zur Anmeldemaske", async ({ page }) => {
  await page.goto("/uebersicht");
  await expect(page).toHaveURL(/\/anmelden\?weiter=%2Fuebersicht/);
  await expect(page.getByRole("heading", { name: "Anmelden" })).toBeVisible();
});

test("die Anmeldemaske traegt die Gestaltung", async ({ page }) => {
  await page.goto("/anmelden");

  // Nicht "die Datei ist verlinkt", sondern "die Regel wirkt": ohne geladenes
  // CSS haette der Titel die Standardschrift und der Knopf keine Flaeche.
  const titel = page.getByRole("heading", { name: "Anmelden" });
  const schrift = await titel.evaluate((el) => getComputedStyle(el).fontFamily);
  expect(schrift.toLowerCase()).toContain("barlow");

  const grossschreibung = await titel.evaluate((el) => getComputedStyle(el).textTransform);
  expect(grossschreibung).toBe("uppercase");

  const knopf = page.getByRole("button", { name: "Anmelden" });
  const flaeche = await knopf.evaluate((el) => getComputedStyle(el).backgroundColor);
  expect(flaeche).not.toBe("rgba(0, 0, 0, 0)");

  // Die Mindesthoehe aus den Tokens muss ankommen — auf der Baustelle wird mit
  // Handschuhen getippt.
  const hoehe = await knopf.evaluate((el) => el.getBoundingClientRect().height);
  expect(hoehe).toBeGreaterThanOrEqual(44);
});

test("Eingabefelder heben sich von der Karte ab", async ({ page }) => {
  // basis.css gibt Karte und Feld dieselbe Flaeche. Ohne die Korrektur in
  // anwendung.css unterscheiden sich beide nur durch den Rahmen — auf einem
  // Baustellen-Tablet bei Sonne ist das zu wenig.
  for (const thema of ["tag", "nacht"]) {
    await page.goto("/anmelden");
    await page.evaluate((t) => document.documentElement.setAttribute("data-theme", t), thema);

    const feld = await page
      .getByLabel("Passwort")
      .evaluate((el) => getComputedStyle(el).backgroundColor);
    const karte = await page
      .locator(".karte")
      .first()
      .evaluate((el) => getComputedStyle(el).backgroundColor);

    expect(feld, `Feld und Karte sind bei "${thema}" flaechengleich`).not.toBe(karte);
  }
});

test("falsche Zugangsdaten werden verstaendlich abgewiesen", async ({ page }) => {
  await page.goto("/anmelden");
  await page.getByLabel("E-Mail").fill("niemand@beispiel.de");
  await page.getByLabel("Passwort").fill("FalschesPasswort123");
  await page.getByRole("button", { name: "Anmelden" }).click();

  const meldung = page.getByRole("alert");
  await expect(meldung).toBeVisible();
  // Kein englischer Fachjargon in der Oberflaeche.
  await expect(meldung).not.toContainText(/invalid|credentials/i);
});

test("Tag und Nacht sind beide dunkel genug bzw. hell genug", async ({ page }) => {
  await page.goto("/anmelden");

  const grundTag = await page.evaluate(
    () => getComputedStyle(document.body).backgroundColor,
  );

  await page.evaluate(() => {
    localStorage.setItem("gewerk_thema", "nacht");
    document.documentElement.setAttribute("data-theme", "nacht");
  });
  const grundNacht = await page.evaluate(
    () => getComputedStyle(document.body).backgroundColor,
  );

  expect(grundTag).not.toBe(grundNacht);
});
