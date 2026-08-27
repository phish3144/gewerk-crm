import type { ReactNode } from "react";

// Eine Kennzahl, die sich aufklappen laesst.
//
// Das ist keine Spielerei: eine Zahl, deren Herkunft man nicht sehen kann,
// wird nicht geglaubt und zu Recht ignoriert. Wer "4.820 EUR nicht beauftragt"
// liest, will wissen, welche vier Buchungen das sind - sonst klickt er einmal
// hin und nie wieder.
export function Kennzahl({
  titel,
  wert,
  zusatz,
  ton = "neutral",
  zeilen,
  leer,
}: {
  titel: string;
  wert: string;
  zusatz?: string;
  ton?: "neutral" | "warnung" | "gefahr";
  zeilen: ReactNode;
  leer: string;
}) {
  const hatZeilen = Array.isArray(zeilen) ? zeilen.length > 0 : Boolean(zeilen);

  return (
    <div className={`karte gestapelt kennzahlkarte ${ton !== "neutral" ? `ton-${ton}` : ""}`}>
      <p className="gruppenlabel">{titel}</p>
      <p className="kennzahl">{wert}</p>
      {zusatz && <p className="zusatz">{zusatz}</p>}

      {hatZeilen ? (
        <details>
          <summary className="zusatz">Woher kommt das?</summary>
          <div className="gestapelt herkunft">{zeilen}</div>
        </details>
      ) : (
        <p className="zusatz">{leer}</p>
      )}
    </div>
  );
}
