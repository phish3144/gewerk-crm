import { type NextRequest } from "next/server";
import { AFRelationship } from "pdf-lib";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { abgesetzteVorbelege, rechnungsDaten } from "@/lib/rechnung";
import { zugferdXml } from "@/lib/zugferd";
import { BELEG_ART_TEXT } from "@/lib/beleg";
import { absatz, fertig, linie, luecke, neueSeite, tabelle, winansi } from "@/lib/pdf";

const euro = new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" });
const menge = new Intl.NumberFormat("de-DE", { maximumFractionDigits: 4 });
const datum = (w: string | null) => (w ? new Date(w).toLocaleDateString("de-DE") : "—");

// Die Rechnung: Sichtfassung und Datensatz in einer Datei.
//
// Beide kommen aus rechnungsDaten() - es gibt keine zweite Datenhaltung fuer
// "die XML-Variante". Weichen sie ab, gilt der strukturierte Teil, und der
// Betrieb haette unbemerkt etwas anderes verschickt, als er gelesen hat.
export async function GET(_anfrage: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!(await aktiveZugehoerigkeit())) return new Response("Nicht angemeldet", { status: 401 });

  const r = await rechnungsDaten(id);
  if (!r) return new Response("Nicht gefunden", { status: 404 });
  const vorbelege = await abgesetzteVorbelege(id);

  const f = await neueSeite();

  absatz(
    f,
    [r.verkaeufer.name, r.verkaeufer.strasse, [r.verkaeufer.plz, r.verkaeufer.ort].filter(Boolean).join(" ")]
      .filter(Boolean)
      .join(" · "),
    { groesse: 8.5, grau: true, abstand: 2 },
  );
  absatz(
    f,
    [
      r.verkaeufer.ust_id ? `USt-IdNr. ${r.verkaeufer.ust_id}` : null,
      r.verkaeufer.steuernummer ? `Steuernummer ${r.verkaeufer.steuernummer}` : null,
    ]
      .filter(Boolean)
      .join(" · "),
    { groesse: 8.5, grau: true, abstand: 18 },
  );

  absatz(f, r.kaeufer.name, { fett: true, abstand: 2 });
  if (r.kaeufer.strasse) absatz(f, r.kaeufer.strasse, { abstand: 2 });
  absatz(f, [r.kaeufer.plz, r.kaeufer.ort].filter(Boolean).join(" "), { abstand: 20 });

  absatz(f, BELEG_ART_TEXT[r.art] ?? r.art, { groesse: 15, fett: true, abstand: 4 });
  absatz(f, `Nr. ${r.nummer}`, { groesse: 12, fett: true, abstand: 10 });

  // § 14 Abs. 4 UStG: Pflichtangaben. Das Leistungsdatum nach Nr. 6 steht hier,
  // nicht im Kleingedruckten - es fehlt in der Praxis am haeufigsten.
  absatz(
    f,
    [
      `Rechnungsdatum: ${datum(r.datum)}`,
      `Leistungsdatum: ${datum(r.leistungsdatum)}`,
      r.faellig_am ? `Zahlbar bis: ${datum(r.faellig_am)}` : null,
      r.betreff,
    ]
      .filter(Boolean)
      .join("\n"),
    { groesse: 9.5, grau: true, abstand: 12 },
  );

  tabelle(
    f,
    ["Pos.", "Bezeichnung", "Menge", "Einzelpreis", "Betrag"],
    [36, 240, 74, 84, 84],
    r.positionen.map((p) => [
      String(p.nr),
      p.bezeichnung,
      `${menge.format(p.menge)} ${p.einheit}`,
      euro.format(p.einzelpreis),
      euro.format(p.gesamt),
    ]),
  );

  linie(f);
  const zeilen: Array<[string, string]> = [["Nettobetrag", euro.format(r.netto)]];
  for (const g of r.steuergruppen) {
    zeilen.push([
      r.reverse_charge ? "Umsatzsteuer (§ 13b UStG)" : `Umsatzsteuer ${menge.format(g.satz)} %`,
      euro.format(r.reverse_charge ? 0 : g.steuer),
    ]);
  }
  zeilen.push(["Bruttobetrag", euro.format(r.brutto)]);

  for (const v of vorbelege) {
    zeilen.push([
      `abzüglich ${v.vorbeleg_nummer} vom ${datum(v.vorbeleg_datum as string)}`,
      `− ${euro.format(Number(v.angerechnet_brutto))}`,
    ]);
  }

  // Rechtsbuendig untereinander: so laesst sich die Aufstellung ueberschlagen.
  tabelle(f, ["", ""], [360, 160], zeilen.map(([t, w]) => [t, w]), {
    groesse: 10,
    linksbuendig: [0],
    mitKopf: false,
  });
  luecke(f, 6);
  absatz(f, `Zahlbetrag: ${euro.format(r.faellig)}`, { groesse: 12, fett: true, abstand: 10 });

  if (r.reverse_charge) {
    absatz(f, "Steuerschuldnerschaft des Leistungsempfängers (§ 13b UStG).", {
      groesse: 9.5,
      abstand: 6,
    });
  }
  if (vorbelege.length > 0) {
    absatz(
      f,
      "Die vereinnahmten Teilentgelte und die darauf entfallende Umsatzsteuer sind abgesetzt " +
        "(§ 14 Abs. 5 Satz 2 UStG).",
      { groesse: 9, grau: true, abstand: 6 },
    );
  }

  // Der Datensatz haengt in derselben Datei. AFRelationship "Alternative" sagt
  // dem Empfaengersystem, dass XML und Sichtfassung dieselbe Rechnung sind -
  // nicht Anhang, nicht Beiwerk.
  const xml = zugferdXml(r);
  await f.dokument.attach(new TextEncoder().encode(xml), "zugferd-invoice.xml", {
    mimeType: "text/xml",
    description: "ZUGFeRD 2.0.1 BASIC Rechnungsdatensatz",
    afRelationship: AFRelationship.Alternative,
    creationDate: new Date(r.datum),
    modificationDate: new Date(r.datum),
  });

  f.dokument.setTitle(winansi(`${BELEG_ART_TEXT[r.art] ?? r.art} ${r.nummer}`));
  f.dokument.setProducer("gewerk");
  f.dokument.setCreator("gewerk");

  const bytes = await fertig(f);
  return new Response(bytes as unknown as BodyInit, {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `inline; filename="${r.nummer}.pdf"`,
      "Cache-Control": "private, no-store",
    },
  });
}
