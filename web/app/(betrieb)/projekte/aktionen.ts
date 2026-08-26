"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { fehlertext } from "@/lib/fehler";
import { alsFeldfehler, type Ergebnis } from "@/lib/formular";

const ZUSTAENDE = ["geplant", "laufend", "abgeschlossen", "storniert"] as const;

function ausFormular(daten: FormData) {
  const text = (n: string) => {
    const w = String(daten.get(n) ?? "").trim();
    return w === "" ? null : w;
  };
  const status = String(daten.get("status") ?? "geplant");

  return {
    bezeichnung: String(daten.get("bezeichnung") ?? "").trim(),
    kunde_id: String(daten.get("kunde_id") ?? ""),
    nummer: text("nummer"),
    strasse: text("strasse"),
    plz: text("plz"),
    ort: text("ort"),
    status: (ZUSTAENDE as readonly string[]).includes(status) ? status : "geplant",
    beginn: text("beginn"),
    ende: text("ende"),
  };
}

function pruefen(w: ReturnType<typeof ausFormular>): Record<string, string> {
  const fehler: Record<string, string> = {};
  if (!w.bezeichnung) fehler["bezeichnung"] = "Eine Bezeichnung wird gebraucht.";
  if (!w.kunde_id) fehler["kunde_id"] = "Bitte einen Kunden wählen.";
  // Dieselbe Regel wie der CHECK projekt_zeitraum_plausibel in der Datenbank.
  if (w.beginn && w.ende && w.ende < w.beginn) {
    fehler["ende"] = "Das Ende kann nicht vor dem Beginn liegen.";
  }
  return fehler;
}

export async function projektAnlegen(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const werte = ausFormular(daten);
  const feldFehler = pruefen(werte);
  if (Object.keys(feldFehler).length > 0) return { feldFehler };

  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return { fehler: "Kein Betrieb ausgewählt." };

  const supabase = await serverKlient();
  const { data, error } = await supabase
    .from("projekt")
    .insert({ ...werte, betrieb_id: aktiv.betrieb_id })
    .select("id")
    .single();

  if (error) return alsFeldfehler(error) ?? { fehler: fehlertext(error) };

  revalidatePath("/projekte");
  redirect(`/projekte/${data.id}`);
}

export async function projektAendern(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const id = String(daten.get("id") ?? "");
  const werte = ausFormular(daten);
  const feldFehler = pruefen(werte);
  if (Object.keys(feldFehler).length > 0) return { feldFehler };

  const supabase = await serverKlient();
  const { error } = await supabase.from("projekt").update(werte).eq("id", id);
  if (error) return alsFeldfehler(error) ?? { fehler: fehlertext(error) };

  revalidatePath("/projekte");
  revalidatePath(`/projekte/${id}`);
  redirect(`/projekte/${id}?gespeichert=1`);
}
