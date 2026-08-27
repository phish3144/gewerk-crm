import { serverKlient } from "@/lib/supabase/server";
import { meinMitarbeiter } from "../zeit/aktionen";
import { Abbruch } from "@/komponenten/Zustand";
import { Materialerfassung } from "./Materialerfassung";
import { alsEuro, alsMenge, alsDatum } from "@/lib/geld";

export default async function MaterialSeite() {
  const mitarbeiter = await meinMitarbeiter();
  if (!mitarbeiter) {
    return (
      <>
        <h1 className="seitentitel">Material</h1>
        <Abbruch>
          Für dieses Konto gibt es in diesem Betrieb keinen Mitarbeiterdatensatz. Ohne ihn lässt
          sich keine Entnahme buchen.
        </Abbruch>
      </>
    );
  }

  const supabase = await serverKlient();

  const { data: projekte } = await supabase
    .from("projekt")
    .select("id, nummer, bezeichnung, status")
    .in("status", ["geplant", "laufend"])
    .order("bezeichnung");

  // Dieselbe Quelle wie bei den Zeiten: die Positionen des festgeschriebenen
  // Auftrags sind die Liste, gegen die der Waechter prueft.
  const { data: positionen } = await supabase
    .from("beleg_position")
    .select("id, position_nr, bezeichnung, einheit, art, beleg!inner(projekt_id, art, status)")
    .eq("beleg.art", "auftrag")
    .neq("beleg.status", "entwurf")
    .order("position_nr");

  const { data: artikel } = await supabase
    .from("artikel")
    .select("id, nummer, bezeichnung, einheit, ek_preis")
    .order("bezeichnung")
    .limit(500);

  const vierzehnTage = new Date(Date.now() - 14 * 864e5).toISOString();
  const { data: letzte, error: letzteFehler } = await supabase
    .from("materialentnahme")
    .select("id, bezeichnung, menge, einheit, ek_preis, position_id, erfasst_am, projekt(bezeichnung)")
    .gte("erfasst_am", vierzehnTage)
    .order("erfasst_am", { ascending: false })
    .limit(50);

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
        <h1 className="seitentitel">Material</h1>
        <p className="zusatz">
          {mitarbeiter.name} · was von der Baustelle verbraucht wurde
        </p>
      </div>

      <Materialerfassung
        mitarbeiterId={mitarbeiter.id}
        projekte={(projekte ?? []).map((p) => ({
          id: p.id,
          text: [p.nummer, p.bezeichnung].filter(Boolean).join(" · "),
          positionen: nachProjekt.get(p.id) ?? [],
        }))}
        artikel={(artikel ?? []).map((a) => ({
          id: a.id,
          text: [a.nummer, a.bezeichnung].filter(Boolean).join(" · "),
          name: a.bezeichnung,
          einheit: a.einheit,
          ek: Number(a.ek_preis ?? 0),
        }))}
      />

      <div className="karte gestapelt">
        <h2 className="kartentitel">Zuletzt entnommen</h2>
        {letzteFehler && (
          <p className="hinweis" role="alert">
            Die Entnahmen konnten nicht geladen werden: {letzteFehler.message}
          </p>
        )}
        {!letzteFehler && (letzte ?? []).length === 0 && (
          <p className="zusatz">In den letzten 14 Tagen wurde nichts gebucht.</p>
        )}
        {(letzte ?? []).map((m) => {
          const projekt = m.projekt as unknown as { bezeichnung: string } | null;
          return (
            <div key={m.id} className="reihe" style={{ justifyContent: "space-between" }}>
              <span>
                {m.bezeichnung}
                <br />
                <span className="zusatz">
                  {projekt?.bezeichnung ?? "Ohne Projekt"} · {alsDatum(m.erfasst_am)}
                  {!m.position_id && " · noch nicht zugeordnet"}
                </span>
              </span>
              <span className="zahl">
                {alsMenge(m.menge)} {m.einheit}
                <br />
                <span className="zusatz">{alsEuro(Number(m.menge) * Number(m.ek_preis ?? 0))}</span>
              </span>
            </div>
          );
        })}
      </div>
    </>
  );
}
