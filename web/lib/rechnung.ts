import { serverKlient } from "@/lib/supabase/server";
import type { RechnungsDaten } from "@/lib/zugferd";

// Eine Quelle fuer beide Fassungen.
//
// Sichtfassung (PDF) und Datensatz (ZUGFeRD-XML) muessen dasselbe sagen -
// weichen sie ab, gilt nach der E-Rechnungsverordnung der strukturierte Teil,
// und der Betrieb hat unbemerkt etwas anderes verschickt, als er gelesen hat.
// Deshalb lesen beide aus dieser Funktion und nirgendwo sonst.
export async function rechnungsDaten(belegId: string): Promise<RechnungsDaten | null> {
  const supabase = await serverKlient();

  const { data: beleg } = await supabase
    .from("beleg")
    .select("*")
    .eq("id", belegId)
    .maybeSingle();
  if (!beleg) return null;

  const { data: positionen } = await supabase
    .from("beleg_position")
    .select("position_nr, art, bezeichnung, menge, einheit, einzelpreis, rabatt_prozent, steuersatz, gesamt")
    .eq("beleg_id", belegId)
    .order("position_nr");

  const { data: betrieb } = await supabase
    .from("betrieb")
    .select("name, strasse, plz, ort, ust_id, steuernummer")
    .eq("id", beleg.betrieb_id)
    .maybeSingle();

  // Kundenanschrift aus der Kopie am Beleg, nicht aus dem Stammsatz: eine
  // festgeschriebene Rechnung muss den uebermittelten Wert behalten. Nur
  // solange sie Entwurf ist, gibt es die Kopie noch nicht.
  let kunde = {
    name: beleg.kunde_name as string | null,
    strasse: beleg.kunde_strasse as string | null,
    plz: beleg.kunde_plz as string | null,
    ort: beleg.kunde_ort as string | null,
    ust_id: beleg.kunde_ust_id as string | null,
  };
  if (!kunde.name) {
    const { data: stamm } = await supabase
      .from("kunde")
      .select("name, strasse, plz, ort, ust_id")
      .eq("id", beleg.kunde_id)
      .maybeSingle();
    if (stamm) kunde = stamm;
  }

  // Absetzung der vereinnahmten Teilentgelte, § 14 Abs. 5 Satz 2 UStG.
  const { data: anrechnungen } = await supabase
    .from("beleg_anrechnung")
    .select("angerechnet_brutto, entgelt_netto, steuerbetrag, steuersatz, status_rc, vorbeleg_nummer, vorbeleg_datum")
    .eq("schlussrechnung_id", belegId);

  const abrechenbar = (positionen ?? []).filter((p) => p.art !== "text" && p.art !== "titel");

  // Je Steuersatz eine Zeile - eine Bruttosumme genuegt der Norm nicht.
  const gruppen = new Map<number, { satz: number; netto: number; steuer: number }>();
  for (const p of abrechenbar) {
    const satz = Number(p.steuersatz ?? 0);
    const netto = Number(p.gesamt ?? 0);
    const bisher = gruppen.get(satz) ?? { satz, netto: 0, steuer: 0 };
    bisher.netto += netto;
    gruppen.set(satz, bisher);
  }
  for (const g of gruppen.values()) g.steuer = Math.round(g.netto * g.satz) / 100;

  const angerechnet = (anrechnungen ?? []).reduce(
    (s, a) => s + Number(a.angerechnet_brutto ?? 0),
    0,
  );

  // Reverse Charge steht an der Zahlung, nicht am Beleg (§ 13b Abs. 4 Satz 2
  // UStG gilt je Vereinnahmung). Fuer die Darstellung zaehlt, ob eine der
  // abgesetzten Zahlungen so eingestuft war.
  const reverseCharge = (anrechnungen ?? []).some((a) => a.status_rc === "rc_13b_nr4");

  return {
    nummer: (beleg.nummer as string) ?? "(Entwurf)",
    datum: beleg.datum as string,
    leistungsdatum: (beleg.leistungsdatum as string | null) ?? null,
    art: beleg.art as string,
    betreff: (beleg.betreff as string | null) ?? null,
    waehrung: "EUR",

    verkaeufer: {
      name: betrieb?.name ?? "",
      strasse: betrieb?.strasse ?? null,
      plz: betrieb?.plz ?? null,
      ort: betrieb?.ort ?? null,
      ust_id: betrieb?.ust_id ?? null,
      steuernummer: betrieb?.steuernummer ?? null,
    },
    kaeufer: {
      name: kunde.name ?? "",
      strasse: kunde.strasse ?? null,
      plz: kunde.plz ?? null,
      ort: kunde.ort ?? null,
      ust_id: kunde.ust_id ?? null,
    },

    positionen: abrechenbar.map((p) => ({
      nr: Number(p.position_nr),
      bezeichnung: String(p.bezeichnung ?? ""),
      menge: Number(p.menge ?? 0),
      einheit: String(p.einheit ?? "Stk"),
      einzelpreis: Number(p.einzelpreis ?? 0),
      gesamt: Number(p.gesamt ?? 0),
      steuersatz: Number(p.steuersatz ?? 0),
    })),

    steuergruppen: [...gruppen.values()].sort((a, b) => b.satz - a.satz),

    netto: Number(beleg.netto ?? 0),
    steuer: Number(beleg.steuer ?? 0),
    brutto: Number(beleg.brutto ?? 0),
    angerechnet,
    faellig: Math.round((Number(beleg.brutto ?? 0) - angerechnet) * 100) / 100,
    faellig_am: (beleg.faelligkeit_am as string | null) ?? null,
    reverse_charge: reverseCharge,
  };
}

// Die abgesetzten Vorbelege gehoeren auch in die Sichtfassung, einzeln und mit
// Nummer - BT-25 und BT-26 der EN 16931.
export async function abgesetzteVorbelege(belegId: string) {
  const supabase = await serverKlient();
  const { data } = await supabase
    .from("beleg_anrechnung")
    .select("vorbeleg_nummer, vorbeleg_datum, angerechnet_brutto, entgelt_netto, steuerbetrag, steuersatz")
    .eq("schlussrechnung_id", belegId)
    .order("vorbeleg_datum");
  return data ?? [];
}
