import { expect, test, type Page } from "@playwright/test";
import { inflateSync } from "node:zlib";
import { KONTEN, klient, kontoBereitstellen } from "./konten";

// Rechnung, PDF und E-Rechnung.
//
// Der Kern der Pruefung ist der Abgleich: Sichtfassung und strukturierter
// Datensatz muessen dasselbe sagen. Weichen sie ab, gilt nach der
// E-Rechnungsverordnung der strukturierte Teil - der Betrieb haette dann
// unbemerkt etwas anderes verschickt, als er gelesen hat.
const LAUF = String(process.env["PRUEF_LAUF"] ?? Date.now());

test.setTimeout(150_000);

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

// Der sichtbare Text eines PDF, so weit fuer diesen Abgleich noetig.
//
// pdf-lib legt die Inhaltsstroeme zusammengepresst ab (FlateDecode), deshalb
// steht im Rohbestand nichts Lesbares. Hier werden alle Stroeme entpackt und
// die Zeichenketten aus den Tj-Anweisungen zusammengesetzt. Kein vollstaendiger
// PDF-Leser - aber genug, um zu belegen, dass dieselbe Zahl in Sichtfassung
// und Datensatz steht.
function pdfStroeme(daten: Buffer): string[] {
  const roh = daten.toString("latin1");
  const stroeme: string[] = [];
  const muster = /stream\r?\n/g;
  let treffer: RegExpExecArray | null;
  while ((treffer = muster.exec(roh)) !== null) {
    const start = treffer.index + treffer[0].length;
    const ende = roh.indexOf("endstream", start);
    if (ende < 0) continue;
    const roher = daten.subarray(start, ende);
    try {
      stroeme.push(inflateSync(roher).toString("utf8"));
    } catch {
      stroeme.push(roher.toString("utf8"));
    }
  }
  return stroeme;
}

function pdfText(daten: Buffer): string {
  let text = "";
  for (const inhalt of pdfStroeme(daten)) {
    // pdf-lib schreibt den Text als Hexzeichenkette (<48616C6C6F> Tj), nicht
    // als Klammerzeichenkette. Beide Formen sind in PDF zulaessig, deshalb hier
    // beide.
    for (const m of inhalt.matchAll(/<([0-9A-Fa-f\s]+)>\s*Tj/g)) {
      const hex = m[1]!.replace(/\s+/g, "");
      let wort = "";
      for (let i = 0; i + 1 < hex.length; i += 2) {
        wort += String.fromCharCode(parseInt(hex.slice(i, i + 2), 16));
      }
      text += wort + "\n";
    }
    for (const m of inhalt.matchAll(/\(((?:\\.|[^\\)])*)\)\s*Tj/g)) {
      text += m[1]!.replace(/\\([()\\])/g, "$1") + "\n";
    }
  }
  return text;
}

async function anmelden(page: Page) {
  await page.goto("/anmelden");
  await page.getByLabel("E-Mail").fill(KONTEN.a.email);
  await page.getByLabel("Passwort").fill(KONTEN.a.passwort);
  await page.getByRole("button", { name: "Anmelden" }).click();
  await expect(page).toHaveURL(/\/uebersicht/);
}

test("Schlussrechnung mit Abschlag: Absetzung, PDF und ZUGFeRD stimmen ueberein", async ({
  page,
}) => {
  const marke = `RE-${LAUF}`;
  await anmelden(page);

  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  const { data: zug } = await supabase.from("benutzer_betrieb").select("betrieb_id").limit(1);
  const betriebId = zug![0]!.betrieb_id as string;

  const { data: ich } = await supabase.auth.getUser();
  const { data: kunde } = await supabase
    .from("kunde")
    .insert({
      betrieb_id: betriebId,
      name: `Bauherr ${marke}`,
      strasse: "Musterweg 1",
      plz: "10115",
      ort: "Berlin",
      zahlungsziel_tage: 14,
    })
    .select("id")
    .single();
  const { data: projekt } = await supabase
    .from("projekt")
    .insert({ betrieb_id: betriebId, kunde_id: kunde!.id, bezeichnung: `Sanierung ${marke}` })
    .select("id")
    .single();

  // Abschlagsrechnung ueber 10.000 netto, festgeschrieben und bezahlt.
  const { data: abschlag } = await supabase
    .from("beleg")
    .insert({
      betrieb_id: betriebId,
      kunde_id: kunde!.id,
      projekt_id: projekt!.id,
      art: "abschlagsrechnung",
      leistungsdatum: new Date().toISOString().slice(0, 10),
      erstellt_von: ich.user!.id,
    })
    .select("id")
    .single();
  await supabase.from("beleg_position").insert({
    betrieb_id: betriebId,
    beleg_id: abschlag!.id,
    position_nr: 1,
    bezeichnung: `1. Abschlag Rohbau ${marke}`,
    menge: 1,
    einheit: "Psch",
    einzelpreis: 10000,
    steuersatz: 19,
  });
  const festAb = await supabase.rpc("beleg_festschreiben", { p_beleg: abschlag!.id });
  expect(festAb.error).toBeNull();

  await supabase.from("zahlung").insert({
    betrieb_id: betriebId,
    beleg_id: abschlag!.id,
    vereinnahmt_am: new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10),
    betrag_brutto: 11900,
    entgelt_netto: 10000,
    steuersatz: 19,
    steuerbetrag: 1900,
    art: "abschlag",
  });

  // Schlussrechnung ueber 25.000 netto.
  const { data: schluss } = await supabase
    .from("beleg")
    .insert({
      betrieb_id: betriebId,
      kunde_id: kunde!.id,
      projekt_id: projekt!.id,
      art: "schlussrechnung",
      leistungsdatum: new Date().toISOString().slice(0, 10),
      erstellt_von: ich.user!.id,
    })
    .select("id")
    .single();
  await supabase.from("beleg_position").insert({
    betrieb_id: betriebId,
    beleg_id: schluss!.id,
    position_nr: 1,
    bezeichnung: `Gesamtleistung ${marke}`,
    menge: 1,
    einheit: "Psch",
    einzelpreis: 25000,
    steuersatz: 19,
  });

  // Ueber die Oberflaeche: absetzen, dann festschreiben.
  await page.goto(`/belege/${schluss!.id}`);
  await page.getByRole("button", { name: "Abschläge jetzt absetzen" }).click();
  await expect(page.getByText(/1 Abschlagszahlung\(en\) abgesetzt/)).toBeVisible({
    timeout: 15000,
  });

  const fest = await supabase.rpc("beleg_festschreiben", { p_beleg: schluss!.id });
  expect(fest.error, "mit Absetzung laesst sie sich festschreiben").toBeNull();
  const nummer = fest.data as string;
  expect(nummer).toMatch(/^RE-\d{4}-\d{5}$/);

  // ------------------------------------------------- PDF und XML abgleichen --
  const pdfAntwort = await page.request.get(`/api/rechnung/${schluss!.id}/pdf`);
  expect(pdfAntwort.status()).toBe(200);
  const pdf = await pdfAntwort.body();
  expect(pdf.subarray(0, 5).toString("ascii")).toBe("%PDF-");

  const xmlAntwort = await page.request.get(`/api/rechnung/${schluss!.id}/xml`);
  expect(xmlAntwort.status()).toBe(200);
  const xml = await xmlAntwort.text();

  // Der Datensatz sagt, was er sagen muss.
  expect(xml, "Rechnungsnummer BT-1").toContain(`<ram:ID>${nummer}</ram:ID>`);
  expect(xml, "Rechnung, nicht Vorauszahlung").toContain("<ram:TypeCode>380</ram:TypeCode>");
  expect(xml, "EN-16931-Profil").toContain("urn:cen.eu:en16931:2017#compliant#");
  expect(xml, "Nettosumme").toContain("<ram:LineTotalAmount>25000.00</ram:LineTotalAmount>");
  expect(xml, "Steuer").toContain("<ram:TaxTotalAmount currencyID=\"EUR\">4750.00</ram:TaxTotalAmount>");
  expect(xml, "Bruttosumme").toContain("<ram:GrandTotalAmount>29750.00</ram:GrandTotalAmount>");
  // BT-113: die vereinnahmten Teilentgelte, § 14 Abs. 5 Satz 2 UStG.
  expect(xml, "angerechnet").toContain("<ram:TotalPrepaidAmount>11900.00</ram:TotalPrepaidAmount>");
  expect(xml, "Zahlbetrag").toContain("<ram:DuePayableAmount>17850.00</ram:DuePayableAmount>");
  expect(xml, "Einheit als UN/ECE-Code").toContain('unitCode="C62"');

  // Wohlgeformt - sonst weist jeder Empfaenger die Rechnung ab, und ein
  // Textbaustein mit einem unmaskierten & genuegt dafuer.
  const { DOMParser } = await import("@xmldom/xmldom");
  const fehler: string[] = [];
  const baum = new DOMParser({
    onError: (grad: string, meldung: string) => {
      if (grad !== "warning") fehler.push(meldung);
    },
  }).parseFromString(xml, "text/xml");
  expect(fehler, "XML ohne Aufbaufehler").toEqual([]);
  expect(baum.documentElement?.nodeName).toBe("rsm:CrossIndustryInvoice");

  // Rechenprobe am Datensatz selbst, nicht an unserer eigenen Rechnung von
  // eben: netto + steuer = brutto, und brutto - angerechnet = zahlbar.
  const wert = (name: string) =>
    Number(baum.getElementsByTagName(`ram:${name}`)[0]?.textContent ?? "NaN");
  expect(wert("LineTotalAmount") + wert("TaxTotalAmount")).toBeCloseTo(wert("GrandTotalAmount"), 2);
  expect(wert("GrandTotalAmount") - wert("TotalPrepaidAmount")).toBeCloseTo(
    wert("DuePayableAmount"),
    2,
  );

  // Und die Sichtfassung sagt dasselbe. Verglichen werden die Zahlen, die
  // Geld bewegen — nicht die Formulierung drumherum.
  const { PDFDocument } = await import("pdf-lib");
  const geladen = await PDFDocument.load(new Uint8Array(pdf));
  expect(geladen.getTitle()).toContain(nummer);

  const sichtbar = pdfText(pdf);
  for (const zahl of ["25.000,00", "4.750,00", "29.750,00", "11.900,00", "17.850,00"]) {
    expect(sichtbar, `${zahl} steht in der Sichtfassung`).toContain(zahl);
  }
  expect(sichtbar, "Rechnungsnummer").toContain(nummer);
  expect(sichtbar, "Leistungsdatum nach § 14 Abs. 4 Nr. 6 UStG").toContain("Leistungsdatum");

  // Der Datensatz haengt in derselben Datei — und zwar derselbe. Das ist die
  // eigentliche Zusicherung dieser Pruefung: Sichtfassung und strukturierte
  // Daten koennen nicht auseinanderlaufen, weil es nur eine Quelle gibt.
  const stroeme = pdfStroeme(pdf);
  const alles = stroeme.join("\n") + pdf.toString("latin1");
  expect(alles, "als Alternative, nicht als Anhang").toContain("/AFRelationship /Alternative");
  expect(alles, "eingebettete Datei").toContain("/EmbeddedFile");

  const eingebettet = stroeme.find((s) => s.includes("<rsm:CrossIndustryInvoice"));
  expect(eingebettet, "der Datensatz liegt im PDF").toBeTruthy();
  expect(
    eingebettet!.trim(),
    "eingebetteter und ausgelieferter Datensatz sind derselbe",
  ).toBe(xml.trim());
});

test.afterAll(async () => {
  if (!bereit) return;
  const supabase = klient();
  await supabase.auth.signInWithPassword({ email: KONTEN.a.email, password: KONTEN.a.passwort });
  // Festgeschriebene Belege sind nach GoBD nicht loeschbar; sie verschwinden
  // mit der Baustelle. Genau so ist es gemeint.
  await supabase.from("projekt").delete().ilike("bezeichnung", `%${LAUF}%`);
  await supabase.from("kunde").delete().ilike("name", `%${LAUF}%`);
});
