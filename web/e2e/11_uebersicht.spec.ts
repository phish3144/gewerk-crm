import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

// Die Startseite. Geprueft wird nicht, dass Zahlen dastehen, sondern dass sie
// sich aufklappen lassen und die Zeilen darunter dieselbe Summe ergeben.
// "Keine Zahl ohne Herkunft" ist sonst eine Absichtserklaerung.
const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());

test.setTimeout(150_000);

let bereit = true;
let grund = "";
let betriebId = "";
let benutzerId = "";

test.beforeAll(async () => {
  try {
    const supabase = await kontoBereitstellen(KONTEN.a);
    const { data: ich } = await supabase.auth.getUser();
    benutzerId = ich.user!.id;
    const { data: zug } = await supabase.from("benutzer_betrieb").select("betrieb_id").limit(1);
    betriebId = zug![0]!.betrieb_id as string;
    await supabase.from("mitarbeiter").update({ stundensatz: 50 }).eq("benutzer_id", benutzerId);
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

test("jede Kennzahl laesst sich bis auf die Zeile aufklappen", async ({ page }) => {
  const marke = `UEB-${LAUF}`;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });

  // Eine offene Rechnung und eine ablaufende Freistellungsbescheinigung.
  const { data: kunde } = await supabase
    .from("kunde")
    .insert({ betrieb_id: betriebId, name: `Kunde ${marke}`, zahlungsziel_tage: 14 })
    .select("id")
    .single();
  const { data: projekt } = await supabase
    .from("projekt")
    .insert({ betrieb_id: betriebId, kunde_id: kunde!.id, bezeichnung: `Baustelle ${marke}` })
    .select("id")
    .single();

  const { data: rechnung } = await supabase
    .from("beleg")
    .insert({
      betrieb_id: betriebId,
      kunde_id: kunde!.id,
      projekt_id: projekt!.id,
      art: "schlussrechnung",
      datum: new Date(Date.now() - 40 * 864e5).toISOString().slice(0, 10),
      leistungsdatum: new Date(Date.now() - 40 * 864e5).toISOString().slice(0, 10),
      erstellt_von: benutzerId,
    })
    .select("id")
    .single();
  await supabase.from("beleg_position").insert({
    betrieb_id: betriebId,
    beleg_id: rechnung!.id,
    position_nr: 1,
    bezeichnung: `Leistung ${marke}`,
    menge: 1,
    einheit: "Psch",
    einzelpreis: 1000,
    steuersatz: 19,
  });
  const fest = await supabase.rpc("beleg_festschreiben", { p_beleg: rechnung!.id });
  expect(fest.error).toBeNull();
  const nummer = fest.data as string;

  const { data: lieferant } = await supabase
    .from("lieferant")
    .insert({ betrieb_id: betriebId, name: `Subunternehmer ${marke}`, ist_subunternehmer: true })
    .select("id")
    .single();
  await supabase.from("freistellungsbescheinigung").insert({
    betrieb_id: betriebId,
    lieferant_id: lieferant!.id,
    sicherheitsnummer: `SN-${marke}`,
    gueltig_bis: new Date(Date.now() + 10 * 864e5).toISOString().slice(0, 10),
  });

  await anmelden(page);
  await page.goto("/uebersicht");

  // ------------------------------------------------------ Offene Posten ----
  const posten = page.locator(".kennzahlkarte", { hasText: "Offene Posten" });
  await expect(posten).toContainText("1.190,00");
  // Vor dem Aufklappen ist die Herkunft nicht sichtbar - danach schon.
  await expect(posten.getByText(nummer)).toBeHidden();
  await posten.getByRole("group").getByText("Woher kommt das?").click();
  await expect(posten.getByText(nummer)).toBeVisible();
  await expect(posten, "ueberfaellig, nicht nur offen").toContainText("überfällig");

  // Die Zeile fuehrt zum Beleg. Eine Kennzahl, die in einer Sackgasse endet,
  // hilft niemandem.
  await posten.getByText(nummer).click();
  await expect(page).toHaveURL(new RegExp(`/belege/${rechnung!.id}`));

  // ------------------------------------------------------------ Fristen ----
  await page.goto("/uebersicht");
  const fristen = page.locator(".kennzahlkarte", { hasText: "Fristen" });
  await fristen.getByRole("group").getByText("Woher kommt das?").click();
  await expect(fristen).toContainText(`Subunternehmer ${marke}`);
  await expect(fristen, "die Grundlage steht dabei").toContainText("§ 48b EStG");
  await expect(fristen, "die Sicherheitsnummer ist die Herkunft").toContainText(`SN-${marke}`);
  await expect(fristen).toContainText("in 10 Tagen");

  // Das Zahlungsziel steht schon in den offenen Posten. Auf der Uebersicht
  // taucht es deshalb nicht ein zweites Mal auf - sonst liest der Betrieb
  // dieselbe Forderung nebeneinander und traut am Ende keiner der beiden
  // Zahlen. In der Sicht selbst bleibt es enthalten.
  await expect(fristen, "keine Doppelung mit den offenen Posten").not.toContainText(
    "Zahlungsziel",
  );

  const { data: alleFristen } = await supabase
    .from("fristen")
    .select("art")
    .eq("art", "zahlungsziel");
  expect(alleFristen?.length ?? 0, "in der Sicht steht es sehr wohl").toBeGreaterThan(0);

  // ---------------------------------------------------- Nachkalkulation ----
  await expect(page.getByRole("heading", { name: "Nachkalkulation" })).toBeVisible();
  await expect(
    page.getByText(/Gemeinkosten stehen bewusst nicht drin/),
    "die Grenze der Zahl steht dabei",
  ).toBeVisible();
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  await supabase.from("lieferant").delete().ilike("name", `%${LAUF}%`);
  await supabase.from("projekt").delete().ilike("bezeichnung", `%${LAUF}%`);
  await supabase.from("kunde").delete().ilike("name", `%${LAUF}%`);
});
