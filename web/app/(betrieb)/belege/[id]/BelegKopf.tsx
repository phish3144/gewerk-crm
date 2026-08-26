"use client";

import { useActionState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { auftragAusAngebot, belegFestschreiben } from "../aktionen";
import { Abbruch } from "@/komponenten/Zustand";
import { istEntwurf } from "@/lib/beleg";
import type { Ergebnis } from "@/lib/formular";

// Die Handlungen am Ende des Belegs. Bewusst unten: erst sieht man, was man
// festschreibt, dann schreibt man fest.
export function BelegKopf({
  id,
  art,
  status,
  nummer,
  hatPositionen,
  speichertNoch,
}: {
  id: string;
  art: string;
  status: string;
  nummer: string | null;
  hatPositionen: boolean;
  speichertNoch: boolean;
}) {
  const [festErgebnis, festschreiben] = useActionState<Ergebnis, FormData>(belegFestschreiben, {});
  const [auftragErgebnis, auftragAnlegen] = useActionState<Ergebnis, FormData>(
    auftragAusAngebot,
    {},
  );

  const entwurf = istEntwurf(status);

  return (
    <div className="karte gestapelt">
      {festErgebnis.fehler && <Abbruch>{festErgebnis.fehler}</Abbruch>}
      {auftragErgebnis.fehler && <Abbruch>{auftragErgebnis.fehler}</Abbruch>}

      {entwurf && (
        <>
          <p className="zusatz">
            Beim Festschreiben vergibt die Datenbank die Nummer. Danach ist der Beleg
            unveränderlich — das ist der Zeitpunkt, ab dem er nach außen gehen darf.
          </p>
          <form action={festschreiben}>
            <input type="hidden" name="id" value={id} />
            {/* Solange eine Position noch gespeichert wird, wuerde das
                Festschreiben einen veralteten Stand einfrieren. */}
            <button type="submit" className="taste taste-primaer" disabled={speichertNoch}>
              {speichertNoch ? "Warte auf Speichern …" : "Festschreiben"}
            </button>
          </form>
          {!hatPositionen && (
            <p className="zusatz">
              Ohne abrechenbare Position weist die Datenbank das Festschreiben ab.
            </p>
          )}
        </>
      )}

      {!entwurf && art === "angebot" && (
        <>
          <p className="zusatz">
            Aus dem Angebot {nummer} entsteht ein Auftrag mit eigenem Nummernkreis. Die
            Positionen werden übernommen; das Angebot bleibt unverändert bestehen.
          </p>
          <form action={auftragAnlegen}>
            <input type="hidden" name="id" value={id} />
            <Absenden laeuft="Auftrag entsteht …">Auftrag daraus machen</Absenden>
          </form>
        </>
      )}
    </div>
  );
}
