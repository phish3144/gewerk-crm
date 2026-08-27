"use client";

import { useRef, useState } from "react";
import { verkleinern } from "@/lib/bild";
import { NACHWEIS_MINDESTLAENGE, nachweisReicht } from "@/lib/nachweis";

export type NachweisStand = { text: string; foto: { blob: Blob; name: string } | null };

export const LEERER_NACHWEIS: NachweisStand = { text: "", foto: null };

// Der Block, der bei "Keine passende Position" erscheint. Er erklaert, warum
// er da ist - eine Pflicht ohne Begruendung wird umgangen, eine mit
// Begruendung wird erfuellt.
//
// Bewusst nicht als Sperre formuliert: der Monteur hat nichts falsch gemacht.
// Er meldet, dass das Leistungsverzeichnis die Arbeit nicht abdeckt, und was
// er jetzt aufschreibt, ist vier Wochen spaeter nicht mehr zu beschaffen.
export function Nachweis({
  stand,
  beiAenderung,
  beschriftung = "Was wurde gemacht?",
}: {
  stand: NachweisStand;
  beiAenderung: (neu: NachweisStand) => void;
  beschriftung?: string;
}) {
  const dateiwahl = useRef<HTMLInputElement>(null);
  const [laedt, setzeLaedt] = useState(false);
  const reicht = nachweisReicht(stand.text, stand.foto);

  async function fotoWaehlen(datei: File) {
    setzeLaedt(true);
    try {
      const klein = await verkleinern(datei);
      beiAenderung({ ...stand, foto: { blob: klein, name: datei.name || "foto.jpg" } });
    } finally {
      setzeLaedt(false);
    }
  }

  return (
    <div className="karte gestapelt nachweis">
      <p className="gruppenlabel">Nachweis</p>
      <p className="zusatz">
        Ohne Position braucht die Buchung einen Nachweis. Auf der Baustelle kostet das zehn
        Sekunden — vier Wochen später ist es nicht mehr zu beschaffen, und ohne Nachweis ist der
        Nachtrag im Streitfall nichts wert.
      </p>

      <label className="eingabe">
        <span>{beschriftung}</span>
        <textarea
          className="feld"
          rows={2}
          value={stand.text}
          onChange={(e) => beiAenderung({ ...stand, text: e.target.value })}
          placeholder="z. B. Bauherr wollte zusätzlich eine Steckdose im Flur"
          aria-describedby="nachweis-stand"
        />
      </label>

      <div className="reihe">
        <button
          type="button"
          className="taste taste-sekundaer"
          onClick={() => dateiwahl.current?.click()}
          disabled={laedt}
        >
          {laedt ? "Einen Moment …" : stand.foto ? "Foto ersetzen" : "Foto hinzufügen"}
        </button>
        {stand.foto && (
          <button
            type="button"
            className="taste taste-sekundaer"
            onClick={() => beiAenderung({ ...stand, foto: null })}
          >
            Foto entfernen
          </button>
        )}
        <input
          ref={dateiwahl}
          type="file"
          accept="image/*"
          capture="environment"
          hidden
          aria-label="Foto als Nachweis"
          onChange={(e) => {
            const datei = e.target.files?.[0];
            if (datei) void fotoWaehlen(datei);
            e.target.value = "";
          }}
        />
      </div>

      <p id="nachweis-stand" className="zusatz" role="status">
        {reicht
          ? stand.foto
            ? "Foto liegt bei."
            : "Notiz reicht."
          : `Noch nicht genug: mindestens ${NACHWEIS_MINDESTLAENGE} Zeichen Notiz oder ein Foto.`}
      </p>
    </div>
  );
}
