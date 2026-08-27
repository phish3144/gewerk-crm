import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

// Von der Meldung zum abrechenbaren Nachtrag - der Weg, den der Betrieb
// wirklich geht, in der Reihenfolge, in der er ihn geht.
const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());
const STUNDENSATZ = 60;

test.setTimeout(120_000);

let bereit = true;
let grund = "";

test.beforeAll(async () => {
  try {
    const supabase = await kontoBereitstellen(KONTEN.a);
    const { data: ich } = await supabase.auth.getUser();
    await supabase
      .from("mitarbeiter")
      .update({ stundensatz: STUNDENSATZ })
      .eq("benutzer_id", ich.user?.id ?? "");
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

// Baustelle samt ungeklaerter Zeitbuchung: 07:00 bis 16:00 minus 30 Minuten
// Pause sind 8,5 Stunden zu 60,00 - also 510,00 Euro nicht beauftragt.
async function baustelleMitMeldung(page: Page, marke: string) {
  await page.goto("/kunden/neu");
  await page.getByLabel("Name").fill(`Nachtragskunde ${marke}`);
  await page.getByRole("button", { name: "Kunde anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Nachtragskunde ${marke}` })).toBeVisible();

  await page.goto("/projekte/neu");
  await page.getByLabel("Bezeichnung").fill(`Nachtragsbaustelle ${marke}`);
  await page.getByLabel("Kunde").selectOption({ label: `Nachtragskunde ${marke}` });
  await page.getByRole("button", { name: "Projekt anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Nachtragsbaustelle ${marke}` })).toBeVisible();
  const projektPfad = new URL(page.url()).pathname;

  await page.goto("/zeit");
  await page.getByLabel("Baustelle").selectOption({ label: `Nachtragsbaustelle ${marke}` });
  await page.getByRole("button", { name: "Vergangenen Tag nachtragen" }).click();
  await page.getByLabel("Von").fill("07:00");
  await page.getByLabel("Bis").fill("16:00");
  await page.getByLabel("Pause (Min.)").fill("30");
  await page.getByLabel("Was gemacht?").or(page.getByLabel("Was wurde gemacht?")).fill(
    `Zaehlerschrank versetzt ${marke}`,
  );
  await page.getByRole("button", { name: "Nachtragen" }).click();

  await expect
    .poll(
      async () => {
        await page.goto("/ungeklaert");
        return await page.getByText(`Zaehlerschrank versetzt ${marke}`).count();
      },
      { timeout: 30000, message: "Meldung im Buero" },
    )
    .toBeGreaterThan(0);

  return projektPfad;
}

test("aus der Meldung wird ein Nachtrag mit Preispflicht, Nummer und Bedenkenanzeige", async ({
  page,
}) => {
  const marke = `NT-${LAUF}`;
  await anmelden(page);
  await baustelleMitMeldung(page, marke);

  // ---------------------------------------------- Meldung auswaehlen --------
  const karte = page.locator("[data-meldung]", {
    hasText: `Zaehlerschrank versetzt ${marke}`,
  });
  await expect(karte).toContainText("510,00");
  await karte
    .getByRole("checkbox", { name: /in den Nachtrag übernehmen/i })
    .check();

  await page.getByRole("button", { name: "Nachtrag erzeugen" }).click();

  // ------------------------------------------------- Nachtragsentwurf -------
  await expect(page).toHaveURL(/\/belege\/[0-9a-f-]{36}/, { timeout: 20000 });
  await expect(page.getByRole("heading", { name: /Nachtrag \(Entwurf\)/ })).toBeVisible();
  // Der Grund fuer den fehlenden Preis steht in der Oberflaeche, nicht nur im
  // Fehlerfall: ab 110 % zaehlen die tatsaechlich erforderlichen Kosten.
  await expect(page.getByText(/tatsächlich erforderlichen Kosten/)).toBeVisible();
  // Die Bezeichnung steht im Entwurf in einem Eingabefeld, nicht als Text: der
  // Nachtrag ist noch aenderbar.
  await expect(
    page.locator(`input[value="Zaehlerschrank versetzt ${marke}"]`),
  ).toBeVisible();

  // Und die Meldung ist aus dem Buero verschwunden.
  await page.goto("/ungeklaert");
  await expect(page.getByText(`Zaehlerschrank versetzt ${marke}`)).toHaveCount(0);

  // -------------------------------------------------- Preispflicht ---------
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  const { data: nachtrag } = await supabase
    .from("beleg")
    .select("id, art, vorgaenger_id, projekt_id, status")
    .eq("art", "nachtrag")
    .order("erstellt_am", { ascending: false })
    .limit(1)
    .single();

  const ohnePreis = await supabase.rpc("beleg_festschreiben", { p_beleg: nachtrag!.id });
  expect(ohnePreis.error?.message, "ohne Preis kein Festschreiben").toContain("ohne Preis");

  const { data: positionen } = await supabase
    .from("beleg_position")
    .select("id, menge, einheit")
    .eq("beleg_id", nachtrag!.id);
  expect(positionen?.length, "eine Position aus der Meldung").toBe(1);
  expect(Number(positionen![0]!.menge), "die Ist-Menge aus der Buchung").toBe(8.5);

  await supabase.from("beleg_position").update({ einzelpreis: 68 }).eq("id", positionen![0]!.id);

  const mitPreis = await supabase.rpc("beleg_festschreiben", { p_beleg: nachtrag!.id });
  expect(mitPreis.error, "mit Preis geht es").toBeNull();
  expect(mitPreis.data as string, "eigener Nummernkreis NA-").toMatch(/^NA-\d{4}-\d{5}$/);

  // ---------------------------------------------- Bedenkenanzeige ----------
  await page.goto(`/belege/${nachtrag!.id}`);
  await page.getByRole("link", { name: /Bedenken anzeigen/ }).click();
  await expect(page.getByRole("heading", { name: "Bedenkenanzeige" })).toBeVisible();

  await page.getByLabel("Betreff").fill(`Zaehlerschrank zu nah an der Gasleitung ${marke}`);
  await page
    .getByLabel("Sachverhalt")
    .fill("Der geplante Standort unterschreitet den Mindestabstand zur Gasleitung.");
  await page.getByLabel("Mögliche Folgen").fill("Die Abnahme durch den Netzbetreiber steht aus.");
  await page.getByRole("button", { name: "Anzeige anlegen" }).click();

  await expect(page).toHaveURL(/\/bedenken\/[0-9a-f-]{36}/, { timeout: 20000 });
  const anzeigeId = new URL(page.url()).pathname.split("/").pop()!;

  // Das Schriftstueck entsteht wirklich, nicht nur der Datensatz.
  const pdf = await page.request.get(`/api/bedenkenanzeige/${anzeigeId}/pdf`);
  expect(pdf.status()).toBe(200);
  expect(pdf.headers()["content-type"]).toContain("application/pdf");
  const bytes = await pdf.body();
  expect(bytes.length, "ein PDF mit Inhalt").toBeGreaterThan(1000);
  expect(bytes.subarray(0, 5).toString("ascii"), "PDF-Kennung").toBe("%PDF-");

  // ------------------------------------------------------- Versand ---------
  await page.getByLabel("Wie versendet").fill("E-Mail mit Lesebestätigung");
  await page.getByLabel("An wen").fill("bauleitung@bauherr.example");
  await page.getByRole("button", { name: "Als versendet festhalten" }).click();

  // Ab hier eingefroren — das Aenderungsformular ist weg.
  await expect(page.getByRole("button", { name: "Entwurf speichern" })).toHaveCount(0, {
    timeout: 15000,
  });
  await expect(page.getByText("bauleitung@bauherr.example")).toBeVisible();

  // Und die Datenbank laesst es auch nicht zu — nicht nur die Oberflaeche.
  const geaendert = await supabase
    .from("bedenkenanzeige")
    .update({ sachverhalt: "Etwas ganz anderes" })
    .eq("id", anzeigeId);
  expect(geaendert.error?.message, "versendet heisst unveraenderlich").toContain("unveraenderlich");
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  // Versendete Bedenkenanzeigen sind mit Absicht nicht loeschbar; sie
  // verschwinden mit der Baustelle. Erst die Belege, dann das Projekt.
  await supabase.from("beleg").delete().ilike("betreff", "%Nachtrag aus%");
  await supabase.from("projekt").delete().ilike("bezeichnung", `%${LAUF}%`);
  await supabase.from("kunde").delete().ilike("name", `%${LAUF}%`);
});
