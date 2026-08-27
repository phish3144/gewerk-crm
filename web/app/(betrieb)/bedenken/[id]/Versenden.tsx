"use client";

import { useActionState } from "react";
import { bedenkenVersenden } from "../aktionen";
import { Absenden } from "@/komponenten/Absenden";

// Der Versand friert den Datensatz ein. Deshalb steht hier ausdruecklich, was
// gleich passiert — ein Knopf, nach dem sich nichts mehr aendern laesst, darf
// nicht wie jeder andere aussehen.
export function Versenden({ id }: { id: string }) {
  const [stand, absenden] = useActionState(bedenkenVersenden, {});

  return (
    <form action={absenden} className="karte gestapelt">
      <input type="hidden" name="id" value={id} />
      <h2 className="kartentitel">Versand festhalten</h2>
      <p className="zusatz">
        Sie versenden das Schreiben selbst — per E-Mail, Fax oder Einschreiben. Hier wird
        festgehalten, wann, wie und an wen. Danach ist die Anzeige unveränderlich: eine
        nachträglich präzisierte Bedenkenanzeige ist im Streitfall wertlos.
      </p>

      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}

      <label className="eingabe">
        <span>Wie versendet</span>
        <input
          className="feld"
          name="versendet_wie"
          required
          placeholder="z. B. E-Mail mit Lesebestätigung"
        />
      </label>
      <label className="eingabe">
        <span>An wen</span>
        <input
          className="feld"
          name="versendet_an"
          required
          placeholder="z. B. bauleitung@auftraggeber.de"
        />
      </label>
      <div>
        <Absenden laeuft="Wird festgehalten …">Als versendet festhalten</Absenden>
      </div>
    </form>
  );
}
