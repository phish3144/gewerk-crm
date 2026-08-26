import { cookies } from "next/headers";
import { serverKlient } from "@/lib/supabase/server";

export const BETRIEB_KEKS = "gewerk_betrieb";

export type Zugehoerigkeit = {
  betrieb_id: string;
  rolle: "inhaber" | "buero" | "monteur";
  name: string;
};

// Alle Betriebe der angemeldeten Person. Die Auswahl kommt aus der Datenbank
// und nicht aus dem Keks — der Keks entscheidet nur, welcher davon aktiv ist.
// Andernfalls waere ein veraenderter Keks ein Weg in einen fremden Betrieb.
export async function meineZugehoerigkeiten(): Promise<Zugehoerigkeit[]> {
  const supabase = await serverKlient();
  const { data, error } = await supabase
    .from("benutzer_betrieb")
    .select("betrieb_id, rolle, betrieb(name)")
    .order("betrieb_id");

  if (error || !data) return [];

  return data.map((zeile) => {
    const betrieb = zeile.betrieb as unknown as { name: string } | null;
    return {
      betrieb_id: zeile.betrieb_id as string,
      rolle: zeile.rolle as Zugehoerigkeit["rolle"],
      name: betrieb?.name ?? "Ohne Namen",
    };
  });
}

// Der aktive Betrieb. Steht im Keks etwas, das nicht in der Liste vorkommt,
// wird es verworfen statt uebernommen.
export async function aktiveZugehoerigkeit(): Promise<Zugehoerigkeit | null> {
  const alle = await meineZugehoerigkeiten();
  if (alle.length === 0) return null;

  const kekse = await cookies();
  const gewaehlt = kekse.get(BETRIEB_KEKS)?.value;
  return alle.find((z) => z.betrieb_id === gewaehlt) ?? alle[0] ?? null;
}
