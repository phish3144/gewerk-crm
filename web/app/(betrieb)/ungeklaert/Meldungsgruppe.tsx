"use client";

import { useActionState, useState } from "react";
import { nachtragErzeugen } from "./aktionen";
import { Absenden } from "@/komponenten/Absenden";
import { alsEuro } from "@/lib/geld";

// Die Auswahl liegt hier, nicht auf der ganzen Seite: ein Nachtrag gehoert zu
// genau einer Baustelle. Meldungen zweier Baustellen zusammenzufassen waere
// fachlich falsch, also ist es gar nicht erst moeglich.
export function Meldungsgruppe({
  projektId,
  betraege,
  children,
}: {
  projektId: string;
  betraege: Record<string, number>;
  children: React.ReactNode;
}) {
  const [gewaehlt, setzeGewaehlt] = useState<string[]>([]);
  const [stand, absenden] = useActionState(nachtragErzeugen, {});

  const summe = gewaehlt.reduce((s, k) => s + (betraege[k] ?? 0), 0);

  function umschalten(schluessel: string, an: boolean) {
    setzeGewaehlt((alt) =>
      an ? [...alt, schluessel] : alt.filter((x) => x !== schluessel),
    );
  }

  // Das Formular umschliesst die Karten ausdruecklich NICHT: jede Karte traegt
  // ihr eigenes Klaerungsformular, und verschachtelte Formulare sind in HTML
  // nicht erlaubt - der Browser wirft das innere weg, und "Als geklaert
  // ablegen" waere ohne Fehlermeldung wirkungslos. Die Auswahl liegt deshalb im
  // Zustand und wandert als verborgene Felder in ein Geschwisterformular.
  return (
    <div className="gestapelt">
      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}

      <MeldungsAuswahl gewaehlt={gewaehlt} umschalten={umschalten}>
        {children}
      </MeldungsAuswahl>

      {gewaehlt.length > 0 && (
        <form action={absenden} className="reihe" style={{ justifyContent: "space-between" }}>
          <input type="hidden" name="projekt_id" value={projektId} />
          {gewaehlt.map((k) => (
            <input key={k} type="hidden" name="meldung" value={k} />
          ))}
          <span className="zusatz">
            {gewaehlt.length} {gewaehlt.length === 1 ? "Meldung" : "Meldungen"} ·{" "}
            <span className="zahl">{alsEuro(summe)}</span>
          </span>
          <Absenden laeuft="Nachtrag entsteht …">Nachtrag erzeugen</Absenden>
        </form>
      )}
    </div>
  );
}

// Der Kontext, ueber den die einzelnen Karten ihren Haken bekommen. Getrennt,
// damit die Meldungskarten Serverkomponenten bleiben koennen — sie zeigen
// Fotos aus dem Dateispeicher, und das gehoert nicht in den Browser verlagert.
import { createContext, useContext } from "react";

const AuswahlKontext = createContext<{
  gewaehlt: string[];
  umschalten: (schluessel: string, an: boolean) => void;
} | null>(null);

function MeldungsAuswahl({
  gewaehlt,
  umschalten,
  children,
}: {
  gewaehlt: string[];
  umschalten: (schluessel: string, an: boolean) => void;
  children: React.ReactNode;
}) {
  return (
    <AuswahlKontext.Provider value={{ gewaehlt, umschalten }}>
      <div className="gestapelt">{children}</div>
    </AuswahlKontext.Provider>
  );
}

export function MeldungsHaken({ schluessel, titel }: { schluessel: string; titel: string }) {
  const kontext = useContext(AuswahlKontext);
  if (!kontext) return null;
  return (
    <label className="reihe" style={{ gap: "var(--abstand-2)" }}>
      <input
        type="checkbox"
        checked={kontext.gewaehlt.includes(schluessel)}
        onChange={(e) => kontext.umschalten(schluessel, e.target.checked)}
        aria-label={`${titel} in den Nachtrag übernehmen`}
      />
      <span className="zusatz">In den Nachtrag</span>
    </label>
  );
}
