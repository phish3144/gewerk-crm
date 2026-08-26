"use client";

import Link from "next/link";
import { useActionState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { anmelden, type Ergebnis } from "./aktionen";

export function AnmeldeFormular({ weiter }: { weiter: string }) {
  const [ergebnis, aktion] = useActionState<Ergebnis, FormData>(anmelden, {});

  return (
    <form action={aktion} className="formular">
      <input type="hidden" name="weiter" value={weiter} />

      {ergebnis.fehler && (
        <p className="hinweis" role="alert">
          {ergebnis.fehler}
        </p>
      )}

      <div className="eingabe">
        <label htmlFor="email">E-Mail</label>
        <input
          id="email"
          name="email"
          type="email"
          className="feld"
          autoComplete="username"
          required
          autoFocus
        />
      </div>

      <div className="eingabe">
        <label htmlFor="passwort">Passwort</label>
        <input
          id="passwort"
          name="passwort"
          type="password"
          className="feld"
          autoComplete="current-password"
          required
        />
      </div>

      <Absenden laeuft="Wird geprüft …">Anmelden</Absenden>

      <p className="zusatz">
        Noch kein Konto? <Link href="/registrieren">Betrieb einrichten</Link>
      </p>
    </form>
  );
}
