"use server";

import { serverKlient, angemeldeteBenutzerin } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";

// Wer bin ich als Mitarbeiter in diesem Betrieb? zeiteintrag zeigt auf
// mitarbeiter, nicht auf benutzer — eine Person kann in zwei Betrieben zwei
// Mitarbeiterdatensaetze haben.
export async function meinMitarbeiter() {
  const aktiv = await aktiveZugehoerigkeit();
  const person = await angemeldeteBenutzerin();
  if (!aktiv || !person) return null;

  const supabase = await serverKlient();
  const { data } = await supabase
    .from("mitarbeiter")
    .select("id, name, stundensatz")
    .eq("benutzer_id", person.id)
    .eq("betrieb_id", aktiv.betrieb_id)
    .maybeSingle();
  return data;
}
