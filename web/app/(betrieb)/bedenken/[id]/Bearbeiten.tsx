"use client";

import { useActionState } from "react";
import { bedenkenAendern } from "../aktionen";
import { Absenden } from "@/komponenten/Absenden";

export function Bearbeiten({
  id,
  betreff,
  sachverhalt,
  folgen,
}: {
  id: string;
  betreff: string;
  sachverhalt: string;
  folgen: string | null;
}) {
  const [stand, absenden] = useActionState(bedenkenAendern, {});

  return (
    <form action={absenden} className="karte gestapelt">
      <input type="hidden" name="id" value={id} />
      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}
      <label className="eingabe">
        <span>Betreff</span>
        <input className="feld" name="betreff" defaultValue={betreff} required />
      </label>
      <label className="eingabe">
        <span>Sachverhalt</span>
        <textarea className="feld" name="sachverhalt" rows={5} defaultValue={sachverhalt} required />
      </label>
      <label className="eingabe">
        <span>Mögliche Folgen</span>
        <textarea className="feld" name="folgen" rows={3} defaultValue={folgen ?? ""} />
      </label>
      <div>
        <Absenden art="taste-sekundaer">Entwurf speichern</Absenden>
      </div>
    </form>
  );
}
