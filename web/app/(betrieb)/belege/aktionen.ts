"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { serverKlient, angemeldeteBenutzerin } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { fehlertext } from "@/lib/fehler";
import type { Ergebnis } from "@/lib/formular";

export async function belegAnlegen(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const kunde_id = String(daten.get("kunde_id") ?? "");
  const projektRoh = String(daten.get("projekt_id") ?? "");
  const betreff = String(daten.get("betreff") ?? "").trim();
  const art = String(daten.get("art") ?? "angebot");

  if (!kunde_id) return { feldFehler: { kunde_id: "Bitte einen Kunden wählen." } };

  const aktiv = await aktiveZugehoerigkeit();
  const person = await angemeldeteBenutzerin();
  if (!aktiv || !person) return { fehler: "Kein Betrieb ausgewählt." };

  const supabase = await serverKlient();
  const { data, error } = await supabase
    .from("beleg")
    .insert({
      betrieb_id: aktiv.betrieb_id,
      kunde_id,
      projekt_id: projektRoh === "" ? null : projektRoh,
      art,
      betreff: betreff === "" ? null : betreff,
      erstellt_von: person.id,
    })
    .select("id")
    .single();

  if (error) return { fehler: fehlertext(error) };

  revalidatePath("/belege");
  redirect(`/belege/${data.id}`);
}

// ---------------------------------------------------------------- Positionen --

const ARTEN = ["leistung", "material", "lohn", "fremdleistung", "text", "titel"] as const;

function zahl(daten: FormData, name: string, standard = 0) {
  const w = String(daten.get(name) ?? "").trim().replace(",", ".");
  if (w === "") return standard;
  const z = Number(w);
  return Number.isFinite(z) ? z : standard;
}

export async function positionAnfuegen(daten: FormData) {
  const beleg_id = String(daten.get("beleg_id") ?? "");
  const art = String(daten.get("art") ?? "leistung");
  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return;

  const supabase = await serverKlient();

  // Die naechste Positionsnummer kommt aus dem Bestand, nicht aus einem Zaehler
  // im Client: zwei offene Fenster wuerden sonst dieselbe Nummer vergeben, und
  // (betrieb_id, beleg_id, position_nr) ist eindeutig.
  const { data: letzte } = await supabase
    .from("beleg_position")
    .select("position_nr")
    .eq("beleg_id", beleg_id)
    .order("position_nr", { ascending: false })
    .limit(1)
    .maybeSingle();

  await supabase.from("beleg_position").insert({
    betrieb_id: aktiv.betrieb_id,
    beleg_id,
    position_nr: (letzte?.position_nr ?? 0) + 1,
    art: (ARTEN as readonly string[]).includes(art) ? art : "leistung",
    bezeichnung: art === "titel" ? "Neuer Titel" : "",
    menge: art === "text" || art === "titel" ? 0 : 1,
    einheit: art === "lohn" ? "h" : "Stk",
  });

  revalidatePath(`/belege/${beleg_id}`);
}

export async function positionAendern(daten: FormData) {
  const id = String(daten.get("id") ?? "");
  const beleg_id = String(daten.get("beleg_id") ?? "");
  const art = String(daten.get("art") ?? "leistung");

  const supabase = await serverKlient();
  const { error } = await supabase
    .from("beleg_position")
    .update({
      art: (ARTEN as readonly string[]).includes(art) ? art : "leistung",
      bezeichnung: String(daten.get("bezeichnung") ?? ""),
      menge: zahl(daten, "menge", 0),
      einheit: String(daten.get("einheit") ?? "Stk") || "Stk",
      einzelpreis: zahl(daten, "einzelpreis", 0),
      rabatt_prozent: zahl(daten, "rabatt_prozent", 0),
      steuersatz: zahl(daten, "steuersatz", 19),
      lohn_anteil: zahl(daten, "lohn_anteil", 0),
      material_anteil: zahl(daten, "material_anteil", 0),
      fremdleistung_anteil: zahl(daten, "fremdleistung_anteil", 0),
      lohn_minuten: Math.round(zahl(daten, "lohn_minuten", 0)),
    })
    .eq("id", id);

  revalidatePath(`/belege/${beleg_id}`);
  return error ? { fehler: fehlertext(error) } : {};
}

export async function positionLoeschen(daten: FormData) {
  const id = String(daten.get("id") ?? "");
  const beleg_id = String(daten.get("beleg_id") ?? "");
  const supabase = await serverKlient();
  await supabase.from("beleg_position").delete().eq("id", id);
  revalidatePath(`/belege/${beleg_id}`);
}

// ------------------------------------------------------------- Festschreiben --

export async function belegFestschreiben(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const id = String(daten.get("id") ?? "");
  const supabase = await serverKlient();

  // Die Datenbank entscheidet. Sie prueft Zugehoerigkeit, Status, ob es
  // ueberhaupt eine abrechenbare Position gibt und - bei Rechnungen - das
  // Leistungsdatum nach § 14 Abs. 4 Nr. 6 UStG.
  const { error } = await supabase.rpc("beleg_festschreiben", { p_beleg: id });
  if (error) return { fehler: fehlertext(error) };

  revalidatePath("/belege");
  revalidatePath(`/belege/${id}`);
  return {};
}

// Angebot -> Auftrag. Die Positionen werden kopiert, nicht verschoben: das
// Angebot bleibt als festgeschriebener Beleg bestehen, der Auftrag ist ein
// eigener Vorgang mit eigenem Nummernkreis.
export async function auftragAusAngebot(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const angebot_id = String(daten.get("id") ?? "");
  const aktiv = await aktiveZugehoerigkeit();
  const person = await angemeldeteBenutzerin();
  if (!aktiv || !person) return { fehler: "Kein Betrieb ausgewählt." };

  const supabase = await serverKlient();
  const { data: angebot, error: lesefehler } = await supabase
    .from("beleg")
    .select("*, beleg_position(*)")
    .eq("id", angebot_id)
    .single();

  if (lesefehler || !angebot) return { fehler: fehlertext(lesefehler) };
  if (angebot.art !== "angebot") return { fehler: "Nur aus einem Angebot lässt sich ein Auftrag machen." };

  const { data: auftrag, error } = await supabase
    .from("beleg")
    .insert({
      betrieb_id: aktiv.betrieb_id,
      kunde_id: angebot.kunde_id,
      projekt_id: angebot.projekt_id,
      art: "auftrag",
      betreff: angebot.betreff,
      vorgaenger_id: angebot.id,
      erstellt_von: person.id,
    })
    .select("id")
    .single();

  if (error) return { fehler: fehlertext(error) };

  const positionen = (angebot.beleg_position ?? []) as Record<string, unknown>[];
  if (positionen.length > 0) {
    const { error: posFehler } = await supabase.from("beleg_position").insert(
      positionen.map((p) => ({
        betrieb_id: aktiv.betrieb_id,
        beleg_id: auftrag.id,
        position_nr: p["position_nr"],
        art: p["art"],
        artikel_id: p["artikel_id"],
        bezeichnung: p["bezeichnung"],
        menge: p["menge"],
        einheit: p["einheit"],
        einzelpreis: p["einzelpreis"],
        rabatt_prozent: p["rabatt_prozent"],
        steuersatz: p["steuersatz"],
        lohn_anteil: p["lohn_anteil"],
        material_anteil: p["material_anteil"],
        fremdleistung_anteil: p["fremdleistung_anteil"],
        lohn_minuten: p["lohn_minuten"],
        gaeb_position: p["gaeb_position"],
      })),
    );
    if (posFehler) return { fehler: fehlertext(posFehler) };
  }

  revalidatePath("/belege");
  redirect(`/belege/${auftrag.id}`);
}
