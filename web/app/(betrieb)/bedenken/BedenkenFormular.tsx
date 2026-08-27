"use client";

import { useActionState } from "react";
import { bedenkenAnlegen } from "./aktionen";
import { Absenden } from "@/komponenten/Absenden";
import { alsDatum } from "@/lib/geld";

type Nachweis = {
  id: string;
  art: string;
  text: string | null;
  r2_key: string | null;
  erfasst_am: string;
};

export function BedenkenFormular({
  projektId,
  nachtragId,
  nachweise,
}: {
  projektId: string;
  nachtragId: string | null;
  nachweise: Nachweis[];
}) {
  const [stand, absenden] = useActionState(bedenkenAnlegen, {});

  return (
    <form action={absenden} className="karte gestapelt">
      <input type="hidden" name="projekt_id" value={projektId} />
      {nachtragId && <input type="hidden" name="nachtrag_id" value={nachtragId} />}

      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}

      <label className="eingabe">
        <span>Betreff</span>
        <input
          className="feld"
          name="betreff"
          required
          placeholder="z. B. Zählerschrank an der vorgesehenen Stelle nicht zulässig"
        />
      </label>

      <label className="eingabe">
        <span>Sachverhalt</span>
        <textarea
          className="feld"
          name="sachverhalt"
          rows={5}
          required
          placeholder="Was ist vorgesehen, was spricht dagegen? Konkret und in ganzen Sätzen — das Schreiben geht so hinaus."
        />
      </label>

      <label className="eingabe">
        <span>Mögliche Folgen</span>
        <textarea
          className="feld"
          name="folgen"
          rows={3}
          placeholder="z. B. Ohne Verlegung ist die Abnahme durch den Netzbetreiber nicht zu erwarten."
        />
      </label>

      {nachweise.length > 0 && (
        <fieldset className="gestapelt" style={{ border: 0, padding: 0, margin: 0 }}>
          <legend className="gruppenlabel">Nachweise von der Baustelle</legend>
          {nachweise.map((n) => (
            <label key={n.id} className="reihe" style={{ gap: "var(--abstand-2)" }}>
              <input type="checkbox" name="nachweis" value={n.id} />
              <span className="zusatz">
                {alsDatum(n.erfasst_am)} · {n.art}
                {n.text ? ` · ${n.text.slice(0, 80)}` : ""}
              </span>
            </label>
          ))}
        </fieldset>
      )}

      <div>
        <Absenden>Anzeige anlegen</Absenden>
      </div>
    </form>
  );
}
