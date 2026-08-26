"use client";

import { useCallback, useState } from "react";
import { Positionen, type Position } from "./Positionen";
import { BelegKopf } from "./BelegKopf";

// Positionen speichern beim Verlassen des Feldes. Ohne gemeinsamen Zaehler
// waere nicht erkennbar, wann das durch ist — und "Festschreiben" wuerde einen
// Beleg einfrieren, dessen letzte Aenderung noch unterwegs ist. Genau das ist
// beim Testen aufgefallen.
//
// Deshalb zaehlt diese Ebene die offenen Speichervorgaenge, zeigt sie an und
// sperrt das Festschreiben, solange etwas laeuft.
export function BelegBearbeiten({
  belegId,
  art,
  status,
  nummer,
  positionen,
  gesperrt,
}: {
  belegId: string;
  art: string;
  status: string;
  nummer: string | null;
  positionen: Position[];
  gesperrt: boolean;
}) {
  const [offen, setzeOffen] = useState(0);
  const melde = useCallback((richtung: 1 | -1) => setzeOffen((n) => Math.max(0, n + richtung)), []);

  return (
    <>
      <div className="karte gestapelt">
        <div className="reihe" style={{ justifyContent: "space-between" }}>
          <h2 className="kartentitel">Positionen</h2>
          {!gesperrt && <SpeicherStand offen={offen} />}
        </div>
        <Positionen
          belegId={belegId}
          positionen={positionen}
          gesperrt={gesperrt}
          melde={melde}
        />
      </div>

      <BelegKopf
        id={belegId}
        art={art}
        status={status}
        nummer={nummer}
        hatPositionen={positionen.length > 0}
        speichertNoch={offen > 0}
      />
    </>
  );
}

function SpeicherStand({ offen }: { offen: number }) {
  return (
    <span className="zusatz" role="status" data-speicherstand={offen > 0 ? "laeuft" : "fertig"}>
      {offen > 0 ? "Änderungen werden gespeichert …" : "Alle Änderungen gespeichert"}
    </span>
  );
}
