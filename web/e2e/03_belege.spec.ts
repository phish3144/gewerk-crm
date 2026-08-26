import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());

let bereit = true;
let grund = "";

test.beforeAll(async () => {
  try {
    await kontoBereitstellen(KONTEN.a);
  } catch (fehler) {
    bereit = false;
    grund = fehler instanceof Error ? fehler.message : String(fehler);
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

// Legt Kunde und Angebot an und gibt die Adresse des Angebots zurueck.
async function angebotMitKunde(page: Page, marke: string) {
  await page.goto("/kunden/neu");
  await page.getByLabel("Name").fill(`Belegkunde ${marke}`);
  await page.getByRole("button", { name: "Kunde anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Belegkunde ${marke}` })).toBeVisible();

  await page.goto("/belege/neu");
  await page.getByLabel("Kunde").selectOption({ label: `Belegkunde ${marke}` });
  await page.getByLabel("Betreff").fill(`Angebot ${marke}`);
  await page.getByRole("button", { name: "Weiter zu den Positionen" }).click();
  await expect(page.getByRole("heading", { name: /Angebot \(Entwurf\)/ })).toBeVisible();
  return new URL(page.url()).pathname;
}

async function positionSetzen(
  page: Page,
  nr: number,
  werte: { bezeichnung: string; menge?: string; einzelpreis?: string },
) {
  await page.getByLabel(`Bezeichnung der Position ${nr}`).fill(werte.bezeichnung);
  if (werte.menge !== undefined) {
    await page.getByLabel(`Menge der Position ${nr}`).fill(werte.menge);
  }
  if (werte.einzelpreis !== undefined) {
    await page.getByLabel(`Einzelpreis der Position ${nr}`).fill(werte.einzelpreis);
  }
  // Speichern geschieht beim Verlassen des Feldes. Die Seite sagt sichtbar, wann
  // es durch ist — darauf wird gewartet, statt eine Wartezeit zu raten.
  await page.locator("h1").click();
  await expect(page.locator("[data-speicherstand]")).toHaveAttribute(
    "data-speicherstand",
    "fertig",
  );
}

test("Angebot mit Positionen: die Datenbank rechnet, nicht der Browser", async ({ page }) => {
  await anmelden(page);
  await angebotMitKunde(page, LAUF);

  await page.getByRole("button", { name: "+ Titel" }).click();
  await expect(page.getByLabel("Bezeichnung der Position 1")).toBeVisible();
  await expect(page.locator("[data-speicherstand]")).toHaveAttribute("data-speicherstand", "fertig");
  await positionSetzen(page, 1, { bezeichnung: "Abbruch" });

  await page.getByRole("button", { name: "+ Leistung" }).click();
  await positionSetzen(page, 2, { bezeichnung: "Fliesen abschlagen", menge: "12", einzelpreis: "45" });

  await page.getByRole("button", { name: "+ Material" }).click();
  await positionSetzen(page, 3, { bezeichnung: "Container", menge: "1", einzelpreis: "280" });

  await page.reload();

  // 12 × 45 = 540, plus 280 = 820 netto; 19 % = 155,80; brutto 975,80.
  // Verglichen wird gegen die Anzeige, die aus beleg.netto/steuer/brutto kommt.
  const summen = page.locator(".summen");
  await expect(summen).toContainText("820,00");
  await expect(summen).toContainText("155,80");
  await expect(summen).toContainText("975,80");
});

test("Festschreiben vergibt eine Nummer und sperrt den Beleg", async ({ page }) => {
  await anmelden(page);
  const adresse = await angebotMitKunde(page, `FEST-${LAUF}`);

  await page.getByRole("button", { name: "+ Leistung" }).click();
  await positionSetzen(page, 1, { bezeichnung: "Montage", menge: "3", einzelpreis: "100" });

  await page.getByRole("button", { name: "Festschreiben" }).click();

  await expect(page.getByRole("heading", { name: /^AN-\d{4}-\d{5}$/ })).toBeVisible();
  await expect(page.getByText("unveränderlich", { exact: false })).toBeVisible();

  // Nach dem Festschreiben bietet die Oberflaeche das Aendern gar nicht mehr an.
  await expect(page.getByRole("button", { name: "Festschreiben" })).toHaveCount(0);
  await expect(page.getByLabel("Bezeichnung der Position 1")).toHaveCount(0);

  // Und ein erneuter Aufruf zeigt weiterhin den gesperrten Zustand.
  await page.goto(adresse);
  await expect(page.getByLabel("Bezeichnung der Position 1")).toHaveCount(0);
});

test("ohne abrechenbare Position weist die Datenbank das Festschreiben ab", async ({ page }) => {
  await anmelden(page);
  await angebotMitKunde(page, `LEER-${LAUF}`);

  // Nur eine Titelzeile: sie gliedert, sie rechnet nicht mit.
  await page.getByRole("button", { name: "+ Titel" }).click();
  await positionSetzen(page, 1, { bezeichnung: "Nur eine Überschrift" });

  await page.getByRole("button", { name: "Festschreiben" }).click();

  const meldung = page.locator(".hinweis[role='alert']");
  await expect(meldung).toContainText("abrechenbare Position");
  await expect(page.getByRole("heading", { name: /Entwurf/ })).toBeVisible();
});

test("aus dem Angebot entsteht ein Auftrag mit eigener Nummer und den Positionen", async ({
  page,
}) => {
  await anmelden(page);
  await angebotMitKunde(page, `AUFTRAG-${LAUF}`);

  await page.getByRole("button", { name: "+ Leistung" }).click();
  await positionSetzen(page, 1, { bezeichnung: "Estrich", menge: "40", einzelpreis: "18" });

  await page.getByRole("button", { name: "Festschreiben" }).click();
  await expect(page.getByRole("heading", { name: /^AN-/ })).toBeVisible();

  await page.getByRole("button", { name: "Auftrag daraus machen" }).click();

  // Der Auftrag ist ein eigener Entwurf mit uebernommenen Positionen.
  await expect(page.getByRole("heading", { name: /Auftrag \(Entwurf\)/ })).toBeVisible();
  await expect(page.getByLabel("Bezeichnung der Position 1")).toHaveValue("Estrich");
  await expect(page.locator(".summen")).toContainText("720,00");

  // Nach dem Festschreiben traegt er das eigene Praefix.
  await page.getByRole("button", { name: "Festschreiben" }).click();
  await expect(page.getByRole("heading", { name: /^AU-\d{4}-\d{5}$/ })).toBeVisible();
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  // Festgeschriebene Belege lassen sich nicht loeschen — das ist der Sinn der
  // Sache. Aufgeraeumt wird nur, was Entwurf geblieben ist.
  const { data: belege } = await supabase
    .from("beleg")
    .select("id, status, kunde(name)")
    .eq("status", "entwurf");
  for (const b of belege ?? []) {
    const k = b.kunde as unknown as { name: string } | null;
    if (k?.name?.includes(LAUF)) {
      await supabase.from("beleg_position").delete().eq("beleg_id", b.id);
      await supabase.from("beleg").delete().eq("id", b.id);
    }
  }
});
