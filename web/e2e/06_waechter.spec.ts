import { expect, test, type Page } from "@playwright/test";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

// Der Nachtragswaechter, Teil 1. Geprueft wird das, was der Betrieb am Abend
// sieht — nicht, dass ein Formular absendbar ist.
const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());
const STUNDENSATZ = 60;

// Jede Pruefung hier legt Kunde, Baustelle und Buchung an und wartet danach
// darauf, dass die Warteschlange gesendet hat. Die 30 Sekunden aus der
// Grundeinstellung reichen dafuer nicht - und ein Zeitablauf sieht aus wie ein
// Fehler der Anwendung, obwohl nur das Budget zu knapp war.
test.setTimeout(90_000);

let bereit = true;
let grund = "";

test.beforeAll(async () => {
  try {
    const supabase = await kontoBereitstellen(KONTEN.a);
    // Der Eurobetrag ist die Botschaft. Damit er nachrechenbar ist, bekommt
    // die Pruefperson einen festen Verrechnungssatz.
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

async function baustelleAnlegen(page: Page, marke: string) {
  await page.goto("/kunden/neu");
  await page.getByLabel("Name").fill(`Waechterkunde ${marke}`);
  await page.getByRole("button", { name: "Kunde anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Waechterkunde ${marke}` })).toBeVisible();

  await page.goto("/projekte/neu");
  await page.getByLabel("Bezeichnung").fill(`Waechterbaustelle ${marke}`);
  await page.getByLabel("Kunde").selectOption({ label: `Waechterkunde ${marke}` });
  await page.getByRole("button", { name: "Projekt anlegen" }).click();
  await expect(page.getByRole("heading", { name: `Waechterbaustelle ${marke}` })).toBeVisible();
}

test("ohne Position bleibt Stopp gesperrt, bis ein Nachweis da ist", async ({ page }) => {
  const marke = `SPERRE-${LAUF}`;
  await anmelden(page);
  await baustelleAnlegen(page, marke);

  await page.goto("/zeit");
  await page.getByLabel("Baustelle").selectOption({ label: `Waechterbaustelle ${marke}` });
  await page.getByRole("button", { name: /Keine passende Position/ }).click();

  const stopp = page.getByRole("button", { name: "Stopp" });
  await expect(stopp, "ohne Nachweis darf nicht abgeschlossen werden").toBeDisabled();

  // Zu kurz reicht nicht — sonst steht am Ende "x" als Nachweis in der Akte.
  await page.getByLabel("Was wurde gemacht?").fill("ja");
  await expect(stopp).toBeDisabled();

  await page.getByLabel("Was wurde gemacht?").fill(`Steckdose im Flur ${marke}`);
  await expect(stopp).toBeEnabled();
  await stopp.click();

  // Angekommen: Buchung und Nachweis, und die Buchung zeigt auf den Nachweis.
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  await expect
    .poll(
      async () => {
        const { data } = await supabase
          .from("zeiteintrag")
          .select("id, nachweis_id")
          .eq("taetigkeit", `Steckdose im Flur ${marke}`);
        return data?.[0]?.nachweis_id ?? null;
      },
      { timeout: 20000, message: "Buchung mit Nachweis" },
    )
    .not.toBeNull();
});

test("nachgetragene Zeit ohne Position erscheint mit Eurobetrag in Ungeklaert", async ({
  page,
}) => {
  const marke = `EURO-${LAUF}`;
  await anmelden(page);
  await baustelleAnlegen(page, marke);

  await page.goto("/zeit");
  await page.getByLabel("Baustelle").selectOption({ label: `Waechterbaustelle ${marke}` });
  await page.getByRole("button", { name: "Vergangenen Tag nachtragen" }).click();

  await page.getByLabel("Von").fill("07:00");
  await page.getByLabel("Bis").fill("16:00");
  await page.getByLabel("Pause (Min.)").fill("30");
  // Ohne Position gibt es kein getrenntes Taetigkeitsfeld: die Notiz aus dem
  // Nachweisblock IST die Taetigkeit. Zwei Felder fuer dasselbe waeren der
  // sichere Weg, dass hinterher das Falsche in der Akte steht.
  await expect(page.getByLabel("Tätigkeit")).toHaveCount(0);

  const nachtragen = page.getByRole("button", { name: "Nachtragen" });
  await expect(nachtragen, "ohne Nachweis nicht nachtragbar").toBeDisabled();

  await page.getByLabel("Was wurde gemacht?").fill(`Zusatzarbeit ${marke}`);
  await expect(nachtragen).toBeEnabled();
  await nachtragen.click();

  // 07:00 bis 16:00 minus 30 Minuten Pause = 8,5 Stunden zu 60,00 = 510,00.
  await expect
    .poll(
      async () => {
        await page.goto("/ungeklaert");
        return await page.getByText(`Zusatzarbeit ${marke}`).count();
      },
      { timeout: 25000, message: "Meldung im Buero" },
    )
    .toBeGreaterThan(0);

  const karte = page.locator("[data-meldung]", { hasText: `Zusatzarbeit ${marke}` });
  await expect(karte).toContainText("510,00");
  await expect(karte).toContainText("8,5 Std");
  await expect(karte, "der Nachweis haengt sichtbar dran").toContainText(
    "Nachweis von der Baustelle",
  );
});

test("Material ohne Position meldet den Einkaufswert und laesst sich klaeren", async ({ page }) => {
  const marke = `MAT-${LAUF}`;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  const { data: zugehoerig } = await supabase.from("benutzer_betrieb").select("betrieb_id").limit(1);
  await supabase.from("artikel").insert({
    betrieb_id: zugehoerig![0]!.betrieb_id,
    nummer: `WA-${marke}`,
    bezeichnung: `Leerrohr ${marke}`,
    einheit: "m",
    ek_preis: 2.5,
  });

  await anmelden(page);
  await baustelleAnlegen(page, marke);

  await page.goto("/material");
  await page.getByLabel("Baustelle").selectOption({ label: `Waechterbaustelle ${marke}` });
  await page.getByLabel("Artikel").selectOption({ label: `WA-${marke} · Leerrohr ${marke}` });
  await page.getByLabel("Menge", { exact: true }).fill("12");
  await page.getByLabel("Wofür wurde das gebraucht?").fill(`Zusatzleitung ${marke}`);
  await page.getByRole("button", { name: "Entnahme buchen" }).click();

  // 12 m zu 2,50 = 30,00.
  await expect
    .poll(
      async () => {
        await page.goto("/ungeklaert");
        return await page.getByText(`Leerrohr ${marke}`).count();
      },
      { timeout: 25000, message: "Materialmeldung im Buero" },
    )
    .toBeGreaterThan(0);

  const karte = page.locator("[data-meldung]", { hasText: `Leerrohr ${marke}` });
  await expect(karte).toContainText("30,00");

  // Ablegen geht nur mit Begruendung. Ohne sie laesst das Formular sich nicht
  // absenden — ein Knopf "erledigt" ohne Text waere in sechs Monaten wertlos.
  await karte.getByRole("button", { name: "Als geklärt ablegen" }).click();
  const ablegen = karte.getByRole("button", { name: "Ablegen", exact: true });
  await ablegen.click();
  await expect(karte, "ohne Begründung bleibt die Meldung stehen").toHaveCount(1);

  await karte.getByLabel("Warum ist das keine Nachforderung?").fill(`Kulanz ${marke}`);
  await ablegen.click();
  await expect(karte).toHaveCount(0, { timeout: 15000 });

  // Die Begruendung ist der eigentliche Wert und steht dauerhaft im Journal.
  const { data: vermerk } = await supabase
    .from("klaerung")
    .select("grund, gegenstand")
    .eq("gegenstand", "materialentnahme")
    .eq("grund", `Kulanz ${marke}`);
  expect(vermerk?.length ?? 0, "ein Klaerungsvermerk").toBe(1);
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });

  // Ueber die Baustelle abraeumen statt Zeile fuer Zeile: die Kaskade nimmt
  // Buchungen, Nachweise und Klaerungen in der richtigen Reihenfolge mit. Von
  // Hand muesste man sie erst sortieren — seit 0021 laesst sich ein Nachweis
  // nicht loeschen, solange eine Buchung ihn braucht.
  await supabase.from("projekt").delete().ilike("bezeichnung", `%${LAUF}%`);
  await supabase.from("kunde").delete().ilike("name", `%${LAUF}%`);
  await supabase.from("artikel").delete().ilike("nummer", `%${LAUF}%`);
});
