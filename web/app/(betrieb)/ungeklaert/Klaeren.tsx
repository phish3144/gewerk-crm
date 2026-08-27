"use client";

import { useActionState, useState } from "react";
import { klaeren } from "./aktionen";
import { Absenden } from "@/komponenten/Absenden";

// Ablegen geht nur mit Begruendung. Ein Knopf "erledigt" ohne Text waere in
// sechs Monaten wertlos — und genau dann wird gefragt, warum diese vier
// Stunden niemand berechnet hat.
export function Klaeren({
  gegenstand,
  gegenstandId,
}: {
  gegenstand: string;
  gegenstandId: string;
}) {
  const [offen, setzeOffen] = useState(false);
  const [stand, absenden] = useActionState(klaeren, {});

  if (!offen) {
    return (
      <button type="button" className="taste taste-sekundaer" onClick={() => setzeOffen(true)}>
        Als geklärt ablegen
      </button>
    );
  }

  return (
    <form action={absenden} className="gestapelt">
      <input type="hidden" name="gegenstand" value={gegenstand} />
      <input type="hidden" name="gegenstand_id" value={gegenstandId} />
      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}
      <label className="eingabe">
        <span>Warum ist das keine Nachforderung?</span>
        <input
          className="feld"
          name="grund"
          required
          placeholder="z. B. Kulanz — im Pauschalpreis enthalten"
        />
      </label>
      <div className="reihe">
        <Absenden art="taste-sekundaer">Ablegen</Absenden>
        <button type="button" className="taste taste-sekundaer" onClick={() => setzeOffen(false)}>
          Abbrechen
        </button>
      </div>
    </form>
  );
}
