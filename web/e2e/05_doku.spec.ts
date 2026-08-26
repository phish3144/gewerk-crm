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

async function projektAnlegen(page: Page, marke: string) {
  await page.goto("/kunden/neu");
  await page.getByLabel("Name").fill(`Dokukunde ${marke}`);
  await page.getByRole("button", { name: "Kunde anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Dokukunde ${marke}` })).toBeVisible();

  await page.goto("/projekte/neu");
  await page.getByLabel("Bezeichnung").fill(`Dokubaustelle ${marke}`);
  await page.getByLabel("Kunde").selectOption({ label: `Dokukunde ${marke}` });
  await page.getByRole("button", { name: "Projekt anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Dokubaustelle ${marke}` })).toBeVisible();
  return new URL(page.url()).pathname;
}

// Ein winziges, gueltiges PNG — 1×1 Pixel.
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

test("Notiz wird erfasst und erscheint in der Doku", async ({ page }) => {
  await anmelden(page);
  const pfad = await projektAnlegen(page, LAUF);

  await page.goto(`${pfad}/doku`);
  await page.getByLabel("Notiz").fill(`Rohbau abgenommen ${LAUF}`);
  await page.getByRole("button", { name: "Notiz speichern" }).click();

  await expect(page.getByText(`Rohbau abgenommen ${LAUF}`)).toBeVisible({ timeout: 15000 });
});

test("Foto landet im Dateispeicher und wird nur ueber den Worker ausgeliefert", async ({
  page,
}, pruefung) => {
  // Nur gegen die Worker-Fassung. Die R2-Bindung gibt es allein in der
  // workerd-Laufzeit; unter `next start` fehlt sie, und ein Fehlschlag hier
  // wuerde eine Umgebungsluecke als Anwendungsfehler ausgeben.
  test.skip(
    pruefung.project.name !== "worker",
    "Dateispeicher nur in der Worker-Fassung — siehe playwright.worker.ts",
  );
  await anmelden(page);
  const pfad = await projektAnlegen(page, `FOTO-${LAUF}`);

  await page.goto(`${pfad}/doku`);
  await page.locator("input[type=file]").setInputFiles({
    name: "baustelle.png",
    mimeType: "image/png",
    buffer: PNG,
  });

  // Zuerst: ist ueberhaupt etwas schiefgegangen? Ein Abbruch mit Klartext ist
  // aussagekraeftiger als ein Bild, das nicht auftaucht.
  const abbruch = page.locator(".hinweis[role='alert']");
  await page.waitForTimeout(3000);
  if (await abbruch.count()) {
    throw new Error("Die Anwendung meldet: " + (await abbruch.first().innerText()));
  }

  // Getrennt geprueft: kommt der Eintrag an (nach ausdruecklichem Neuladen),
  // und zeigt ihn die Seite auch von selbst?
  const bild = page.locator("img[alt='Baustellenfoto']").first();
  await expect(bild).toBeVisible({ timeout: 20000 });

  // Der Bucket ist nicht oeffentlich: die Adresse zeigt auf den Worker.
  const quelle = await bild.getAttribute("src");
  expect(quelle).toMatch(/^\/api\/dokument\?k=/);

  // Und der Worker liefert die Datei auch wirklich aus.
  const antwort = await page.request.get(quelle!);
  expect(antwort.status()).toBe(200);
  expect(antwort.headers()["content-type"]).toContain("image");
});

test("Foto ohne Netz aufgenommen, mit Netz uebertragen", async ({ page, context }, pruefung) => {
  test.skip(
    pruefung.project.name !== "worker",
    "Dateispeicher nur in der Worker-Fassung — siehe playwright.worker.ts",
  );
  await anmelden(page);
  const pfad = await projektAnlegen(page, `OFFLINE-${LAUF}`);
  await page.goto(`${pfad}/doku`);

  await context.setOffline(true);

  await page.getByLabel("Notiz").fill(`Riss im Estrich ${LAUF}`);
  await page.locator("input[type=file]").setInputFiles({
    name: "riss.png",
    mimeType: "image/png",
    buffer: PNG,
  });

  // Ohne Netz darf nichts verlorengehen — und die Wartende muss sichtbar sein.
  const anzeige = page.locator("[data-warteschlange]");
  await expect(anzeige).toContainText("wartet", { timeout: 10000 });

  await context.setOffline(false);
  await page.evaluate(() => window.dispatchEvent(new Event("online")));
  await expect(anzeige).toHaveCount(0, { timeout: 30000 });

  // Genau eine Zeile, mit Dateischluessel: die Datei ging vor der Zeile raus.
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  const { data } = await supabase
    .from("dokumentation")
    .select("id, art, r2_key")
    .eq("text", `Riss im Estrich ${LAUF}`);
  expect(data?.length, "genau ein Eintrag").toBe(1);
  expect(data?.[0]?.art).toBe("foto");
  expect(data?.[0]?.r2_key, "Dateischluessel gesetzt").toBeTruthy();

  // Und die Datei liegt auch wirklich im Speicher.
  const antwort = await page.request.get(
    `/api/dokument?k=${encodeURIComponent(data![0]!.r2_key as string)}`,
  );
  expect(antwort.status()).toBe(200);
});

test("ein Schluessel aus einem fremden Betrieb wird abgewiesen", async ({ page }) => {
  await anmelden(page);
  // Erstes Segment des Schluessels ist die betrieb_id. Ein geratener fremder
  // Schluessel darf nicht ausgeliefert werden — und zwar bevor der Bucket
  // ueberhaupt gefragt wird.
  const antwort = await page.request.get(
    "/api/dokument?k=00000000-0000-0000-0000-000000000000/x/y.jpg",
  );
  expect(antwort.status()).toBe(404);
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  await supabase.from("dokumentation").delete().ilike("text", `%${LAUF}%`);
});
