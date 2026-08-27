"use server";

import { revalidatePath } from "next/cache";
import { serverKlient, angemeldeteBenutzerin } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { fehlertext } from "@/lib/fehler";

const GEGENSTAENDE = ["zeiteintrag", "materialentnahme", "position_mehrmenge"] as const;
type Gegenstand = (typeof GEGENSTAENDE)[number];

// Eine Meldung verschwindet nicht durch Wegsehen, sondern durch eine
// Begruendung. Die landet ueber den Journaltrigger aus 0020 dauerhaft im
// Journal — sechs Monate spaeter steht dort, warum diese vier Stunden niemand
// berechnet hat.
export async function klaeren(
  _stand: { fehler?: string } | undefined,
  formular: FormData,
): Promise<{ fehler?: string }> {
  const gegenstand = String(formular.get("gegenstand") ?? "");
  const gegenstandId = String(formular.get("gegenstand_id") ?? "");
  const grund = String(formular.get("grund") ?? "").trim();

  if (!GEGENSTAENDE.includes(gegenstand as Gegenstand)) {
    return { fehler: "Unbekannte Art der Meldung." };
  }
  if (grund === "") {
    return { fehler: "Ohne Begründung nicht. Sie ist der eigentliche Wert des Vermerks." };
  }

  const aktiv = await aktiveZugehoerigkeit();
  const person = await angemeldeteBenutzerin();
  if (!aktiv || !person) return { fehler: "Nicht angemeldet." };

  const supabase = await serverKlient();
  // betrieb_id aus der Sitzung, nie aus dem Formular.
  const { error } = await supabase.from("klaerung").insert({
    betrieb_id: aktiv.betrieb_id,
    gegenstand,
    gegenstand_id: gegenstandId,
    grund,
    geklaert_von: person.id,
  });
  if (error) return { fehler: fehlertext(error) };

  revalidatePath("/ungeklaert");
  revalidatePath("/uebersicht");
  return {};
}
