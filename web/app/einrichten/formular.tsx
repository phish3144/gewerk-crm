"use client";

import { useActionState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { betriebGruenden, type Ergebnis } from "./aktionen";

export function EinrichtenFormular({
  nameBekannt,
  vorgeschlagenerName,
}: {
  nameBekannt: boolean;
  vorgeschlagenerName: string;
}) {
  const [ergebnis, aktion] = useActionState<Ergebnis, FormData>(betriebGruenden, {});

  return (
    <form action={aktion} className="formular">
      {ergebnis.fehler && (
        <p className="hinweis" role="alert">
          {ergebnis.fehler}
        </p>
      )}

      {!nameBekannt && (
        <div className="eingabe">
          <label htmlFor="anzeigename">Ihr Name</label>
          <input
            id="anzeigename"
            name="anzeigename"
            className="feld"
            autoComplete="name"
            defaultValue={vorgeschlagenerName}
            required
          />
        </div>
      )}

      <div className="eingabe">
        <label htmlFor="name">Name des Betriebs</label>
        <input
          id="name"
          name="name"
          className="feld"
          placeholder="z. B. Baumeister GmbH"
          required
          autoFocus
        />
      </div>

      <Absenden laeuft="Wird angelegt …">Betrieb anlegen</Absenden>
    </form>
  );
}
