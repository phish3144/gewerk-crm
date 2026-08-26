"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { fehlertext } from "@/lib/fehler";
import { alsFeldfehler, type Ergebnis } from "@/lib/formular";

function ausFormular(daten: FormData) {
  const text = (n: string) => {
    const w = String(daten.get(n) ?? "").trim();
    return w === "" ? null : w;
  };
  const zahl = (n: string, standard: number) => {
    const w = String(daten.get(n) ?? "").trim().replace(",", ".");
    const z = w === "" ? standard : Number(w);
    return Number.isFinite(z) ? z : standard;
  };

  return {
    name: String(daten.get("name") ?? "").trim(),
    nummer: text("nummer"),
    strasse: text("strasse"),
    plz: text("plz"),
    ort: text("ort"),
    ust_id: text("ust_id"),
    reverse_charge_bau: daten.get("reverse_charge_bau") === "on",
    zahlungsziel_tage: zahl("zahlungsziel_tage", 14),
    skonto_prozent: zahl("skonto_prozent", 0),
    skonto_tage: zahl("skonto_tage", 0),
  };
}

function pruefen(werte: ReturnType<typeof ausFormular>): Record<string, string> {
  const fehler: Record<string, string> = {};
  if (!werte.name) fehler["name"] = "Ein Name wird gebraucht.";
  if (werte.zahlungsziel_tage < 0) fehler["zahlungsziel_tage"] = "Das Zahlungsziel kann nicht negativ sein.";
  // Die Datenbank erzwingt 0 <= skonto < 100. Hier steht dieselbe Regel, damit
  // die Nutzerin sie am Feld sieht statt als Abbruch nach dem Absenden.
  if (werte.skonto_prozent < 0 || werte.skonto_prozent >= 100) {
    fehler["skonto_prozent"] = "Skonto muss zwischen 0 und unter 100 Prozent liegen.";
  }
  if (werte.skonto_tage < 0) fehler["skonto_tage"] = "Die Skontofrist kann nicht negativ sein.";
  return fehler;
}

export async function kundeAnlegen(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const werte = ausFormular(daten);
  const feldFehler = pruefen(werte);
  if (Object.keys(feldFehler).length > 0) return { feldFehler };

  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return { fehler: "Kein Betrieb ausgewählt." };

  const supabase = await serverKlient();
  const { data, error } = await supabase
    .from("kunde")
    .insert({ ...werte, betrieb_id: aktiv.betrieb_id })
    .select("id")
    .single();

  if (error) return alsFeldfehler(error) ?? { fehler: fehlertext(error) };

  revalidatePath("/kunden");
  redirect(`/kunden/${data.id}`);
}

export async function kundeAendern(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const id = String(daten.get("id") ?? "");
  const werte = ausFormular(daten);
  const feldFehler = pruefen(werte);
  if (Object.keys(feldFehler).length > 0) return { feldFehler };

  const supabase = await serverKlient();
  // Kein betrieb_id im Filter: die Policy laesst ohnehin nur eigene Zeilen zu.
  // Ein zusaetzlicher Filter waere doppelt gemoppelt und wuerde vortaeuschen,
  // die Trennung haenge an dieser Zeile.
  const { error } = await supabase.from("kunde").update(werte).eq("id", id);
  if (error) return alsFeldfehler(error) ?? { fehler: fehlertext(error) };

  revalidatePath("/kunden");
  revalidatePath(`/kunden/${id}`);
  redirect(`/kunden/${id}?gespeichert=1`);
}
