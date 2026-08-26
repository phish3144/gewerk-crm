"use client";

import Link from "next/link";
import { useActionState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { registrieren, type Ergebnis } from "@/app/anmelden/aktionen";

export function RegistrierFormular() {
  const [ergebnis, aktion] = useActionState<Ergebnis, FormData>(registrieren, {});

  // Nach der Bestaetigungsmail bleibt nur der Hinweis stehen: das Formular
  // erneut anzubieten wuerde nur einen zweiten Versuch mit derselben Adresse
  // provozieren.
  if (ergebnis.hinweis) {
    return (
      <div className="gestapelt">
        <p className="hinweis hinweis-freundlich" role="status">
          {ergebnis.hinweis}
        </p>
        <p className="zusatz">
          Schon bestätigt? <Link href="/anmelden">Zur Anmeldung</Link>
        </p>
      </div>
    );
  }

  return (
    <form action={aktion} className="formular">
      {ergebnis.fehler && (
        <p className="hinweis" role="alert">
          {ergebnis.fehler}
        </p>
      )}

      <div className="eingabe">
        <label htmlFor="name">Ihr Name</label>
        <input id="name" name="name" className="feld" autoComplete="name" required autoFocus />
      </div>

      <div className="eingabe">
        <label htmlFor="email">E-Mail</label>
        <input
          id="email"
          name="email"
          type="email"
          className="feld"
          autoComplete="username"
          required
        />
      </div>

      <div className="eingabe">
        <label htmlFor="passwort">Passwort</label>
        <input
          id="passwort"
          name="passwort"
          type="password"
          className="feld"
          autoComplete="new-password"
          minLength={8}
          required
        />
        <p className="zusatz">Mindestens 8 Zeichen.</p>
      </div>

      <Absenden laeuft="Wird angelegt …">Konto anlegen</Absenden>

      <p className="zusatz">
        Schon ein Konto? <Link href="/anmelden">Anmelden</Link>
      </p>
    </form>
  );
}
