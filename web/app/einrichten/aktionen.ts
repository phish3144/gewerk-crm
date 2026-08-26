"use server";

import { redirect } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { fehlertext } from "@/lib/fehler";

export type Ergebnis = { fehler?: string };

export async function betriebGruenden(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const name = String(daten.get("name") ?? "").trim();
  const anzeigename = String(daten.get("anzeigename") ?? "").trim();
  if (!name) return { fehler: "Der Betrieb braucht einen Namen." };

  const supabase = await serverKlient();

  // Erst das Konto: betrieb_gruenden setzt die benutzer-Zeile voraus, und sie
  // fehlt, wenn die Registrierung ueber eine Bestaetigungsmail lief — dann kam
  // die Anmeldung erst nach dem Klick zustande.
  if (anzeigename) {
    const { error } = await supabase.rpc("konto_anlegen", { p_anzeigename: anzeigename });
    if (error) return { fehler: fehlertext(error) };
  }

  const { error } = await supabase.rpc("betrieb_gruenden", { p_name: name });
  if (error) return { fehler: fehlertext(error) };

  redirect("/uebersicht");
}
