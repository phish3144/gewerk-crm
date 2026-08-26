import { serverKlient } from "@/lib/supabase/server";
import { meinMitarbeiter } from "./aktionen";
import { Zeiterfassung } from "./Zeiterfassung";
import { Abbruch } from "@/komponenten/Zustand";
import { ErfassteZeiten, type Zeile } from "./ErfassteZeiten";

export default async function ZeitSeite() {
  const mitarbeiter = await meinMitarbeiter();
  if (!mitarbeiter) {
    return (
      <>
        <h1 className="seitentitel">Zeiten</h1>
        <Abbruch>
          Für dieses Konto gibt es in diesem Betrieb keinen Mitarbeiterdatensatz. Ohne ihn lässt
          sich keine Zeit erfassen — der Inhaber legt ihn beim Aufnehmen an.
        </Abbruch>
      </>
    );
  }

  const supabase = await serverKlient();

  // Projekte, auf die gebucht werden kann, samt den Positionen des
  // dazugehoerigen Auftrags. Das Leistungsverzeichnis des Auftrags ist die
  // Liste, gegen die der Waechter spaeter prueft.
  const { data: projekte } = await supabase
    .from("projekt")
    .select("id, nummer, bezeichnung, ort, status")
    .in("status", ["geplant", "laufend"])
    .order("bezeichnung");

  const { data: positionen } = await supabase
    .from("beleg_position")
    .select("id, position_nr, bezeichnung, einheit, menge, art, beleg!inner(projekt_id, art, status)")
    .eq("beleg.art", "auftrag")
    .neq("beleg.status", "entwurf")
    .order("position_nr");

  const vierzehnTage = new Date(Date.now() - 14 * 864e5).toISOString();
  const { data: meine } = await supabase
    .from("zeiteintrag")
    .select("id, beginn, ende, pause_minuten, taetigkeit, position_id, projekt(bezeichnung)")
    .eq("mitarbeiter_id", mitarbeiter.id)
    .gte("beginn", vierzehnTage)
    .order("beginn", { ascending: false });

  const nachProjekt = new Map<string, { id: string; nr: number; text: string; einheit: string }[]>();
  for (const p of positionen ?? []) {
    const beleg = p.beleg as unknown as { projekt_id: string | null } | null;
    if (!beleg?.projekt_id) continue;
    if (p.art === "text" || p.art === "titel") continue;
    const liste = nachProjekt.get(beleg.projekt_id) ?? [];
    liste.push({ id: p.id, nr: p.position_nr, text: p.bezeichnung, einheit: p.einheit });
    nachProjekt.set(beleg.projekt_id, liste);
  }

  return (
    <>
      <div>
        <h1 className="seitentitel">Zeiten</h1>
        <p className="zusatz">
          {mitarbeiter.name} · letzte 14 Tage ({(meine ?? []).length} Einträge)
        </p>
      </div>

      <Zeiterfassung
        mitarbeiterId={mitarbeiter.id}
        projekte={(projekte ?? []).map((p) => ({
          id: p.id,
          text: [p.nummer, p.bezeichnung].filter(Boolean).join(" · "),
          positionen: nachProjekt.get(p.id) ?? [],
        }))}
      />

      <div className="karte gestapelt">
        <h2 className="kartentitel">Erfasst</h2>
        <ErfassteZeiten
          gespeichert={(meine ?? []).map((z): Zeile => {
            const projekt = z.projekt as unknown as { bezeichnung: string } | null;
            return {
              id: z.id,
              projekt: projekt?.bezeichnung ?? "Ohne Projekt",
              beginn: z.beginn,
              ende: z.ende,
              pause: z.pause_minuten ?? 0,
              taetigkeit: z.taetigkeit,
              zugeordnet: Boolean(z.position_id),
            };
          })}
          projektNamen={Object.fromEntries((projekte ?? []).map((p) => [p.id, p.bezeichnung]))}
        />
      </div>
    </>
  );
}
