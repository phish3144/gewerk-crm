"use client";

import { useRef, useTransition } from "react";
import { positionAendern, positionAnfuegen, positionLoeschen } from "../aktionen";
import { POSITION_ART_TEXT, rechnetMit } from "@/lib/beleg";
import { alsEuro } from "@/lib/geld";

export type Position = {
  id: string;
  position_nr: number;
  art: string;
  bezeichnung: string;
  menge: string | number;
  einheit: string;
  einzelpreis: string | number;
  rabatt_prozent: string | number;
  steuersatz: string | number;
  lohn_anteil: string | number;
  material_anteil: string | number;
  fremdleistung_anteil: string | number;
  lohn_minuten: number;
  gesamt: string | number | null;
};

const ARTEN = ["leistung", "material", "lohn", "fremdleistung", "text", "titel"] as const;

export function Positionen({
  belegId,
  positionen,
  gesperrt,
  melde,
}: {
  belegId: string;
  positionen: Position[];
  gesperrt: boolean;
  melde: (richtung: 1 | -1) => void;
}) {
  const [laeuft, starte] = useTransition();

  if (gesperrt) {
    return <GesperrteListe positionen={positionen} />;
  }

  return (
    <div className="gestapelt">
      {positionen.length === 0 && (
        <p className="zusatz">Noch keine Position. Fügen Sie die erste hinzu.</p>
      )}

      {positionen.map((p) => (
        <PositionZeile key={p.id} belegId={belegId} position={p} melde={melde} />
      ))}

      <div className="reihe">
        {ARTEN.map((art) => (
          <form
            key={art}
            action={(daten) => {
              daten.set("beleg_id", belegId);
              daten.set("art", art);
              melde(1);
              starte(async () => {
                await positionAnfuegen(daten);
                melde(-1);
              });
            }}
          >
            <button type="submit" className="taste taste-sekundaer" disabled={laeuft}>
              + {POSITION_ART_TEXT[art]}
            </button>
          </form>
        ))}
      </div>
    </div>
  );
}

function PositionZeile({
  belegId,
  position,
  melde,
}: {
  belegId: string;
  position: Position;
  melde: (richtung: 1 | -1) => void;
}) {
  const formular = useRef<HTMLFormElement>(null);
  const [laeuft, starte] = useTransition();

  // Gespeichert wird beim Verlassen des Feldes. Ein eigener Speichern-Knopf je
  // Zeile waere bei zwanzig Positionen zwanzig zusaetzliche Klicks; ein
  // Sammel-Speichern wuerde die Summen bis zum Schluss falsch stehen lassen.
  function sichern() {
    const f = formular.current;
    if (!f) return;
    const daten = new FormData(f);
    melde(1);
    starte(async () => {
      await positionAendern(daten);
      melde(-1);
    });
  }

  const istGliederung = !rechnetMit(position.art);

  return (
    <form
      ref={formular}
      className={istGliederung ? "karte positionszeile gliederung" : "karte positionszeile"}
      onBlur={sichern}
      aria-busy={laeuft}
    >
      <input type="hidden" name="id" value={position.id} />
      <input type="hidden" name="beleg_id" value={belegId} />

      <div className="positionskopf">
        <span className="zahl positionsnummer">{position.position_nr}</span>

        <select
          name="art"
          className="feld"
          defaultValue={position.art}
          aria-label={`Art der Position ${position.position_nr}`}
          onChange={sichern}
          style={{ width: "9rem" }}
        >
          {ARTEN.map((a) => (
            <option key={a} value={a}>
              {POSITION_ART_TEXT[a]}
            </option>
          ))}
        </select>

        <input
          name="bezeichnung"
          className="feld"
          defaultValue={position.bezeichnung}
          placeholder={istGliederung ? "Überschrift oder Text" : "Was wird geleistet?"}
          aria-label={`Bezeichnung der Position ${position.position_nr}`}
          style={{ flex: 1, minWidth: "14rem" }}
        />

        <button
          type="submit"
          className="taste taste-gefahr"
          formAction={(daten) => {
            daten.set("id", position.id);
            daten.set("beleg_id", belegId);
            melde(1);
            starte(async () => {
              await positionLoeschen(daten);
              melde(-1);
            });
          }}
          aria-label={`Position ${position.position_nr} löschen`}
        >
          Löschen
        </button>
      </div>

      {/* Text- und Titelzeilen rechnen nicht mit; Mengenfelder waeren dort nur
          eine Einladung, etwas einzutragen, das nirgends ankommt. */}
      {!istGliederung && (
        <>
          <div className="positionswerte">
            <label>
              <span className="gruppenlabel">Menge</span>
              <input
                name="menge"
                type="number"
                step="0.0001"
                min="0"
                className="feld zahl"
                aria-label={`Menge der Position ${position.position_nr}`}
                defaultValue={String(position.menge)}
              />
            </label>
            <label>
              <span className="gruppenlabel">Einheit</span>
              <input
                name="einheit"
                className="feld"
                aria-label={`Einheit der Position ${position.position_nr}`}
                defaultValue={position.einheit}
              />
            </label>
            <label>
              <span className="gruppenlabel">Einzelpreis</span>
              <input
                name="einzelpreis"
                type="number"
                step="0.0001"
                className="feld zahl"
                aria-label={`Einzelpreis der Position ${position.position_nr}`}
                defaultValue={String(position.einzelpreis)}
              />
            </label>
            <label>
              <span className="gruppenlabel">Rabatt %</span>
              <input
                name="rabatt_prozent"
                type="number"
                step="0.01"
                min="0"
                max="100"
                className="feld zahl"
                aria-label={`Rabatt der Position ${position.position_nr} in Prozent`}
                defaultValue={String(position.rabatt_prozent)}
              />
            </label>
            <label>
              <span className="gruppenlabel">USt %</span>
              <input
                name="steuersatz"
                type="number"
                step="0.01"
                min="0"
                className="feld zahl"
                aria-label={`Steuersatz der Position ${position.position_nr} in Prozent`}
                defaultValue={String(position.steuersatz)}
              />
            </label>
            <span className="positionssumme">
              <span className="gruppenlabel">Summe</span>
              {/* Aus der Datenbank, nicht aus dem Browser gerechnet: gesamt ist
                  eine generierte Spalte. */}
              <span className="zahl">{alsEuro(position.gesamt)}</span>
            </span>
          </div>

          <details className="kalkulation">
            <summary className="zusatz">Kalkulation je Einheit</summary>
            <div className="positionswerte">
              <label>
                <span className="gruppenlabel">Lohn €</span>
                <input name="lohn_anteil" aria-label={`Lohnanteil der Position ${position.position_nr}`} type="number" step="0.01" className="feld zahl"
                  defaultValue={String(position.lohn_anteil)} />
              </label>
              <label>
                <span className="gruppenlabel">Material €</span>
                <input name="material_anteil" aria-label={`Materialanteil der Position ${position.position_nr}`} type="number" step="0.01" className="feld zahl"
                  defaultValue={String(position.material_anteil)} />
              </label>
              <label>
                <span className="gruppenlabel">Fremd €</span>
                <input name="fremdleistung_anteil" aria-label={`Fremdleistungsanteil der Position ${position.position_nr}`} type="number" step="0.01" className="feld zahl"
                  defaultValue={String(position.fremdleistung_anteil)} />
              </label>
              <label>
                <span className="gruppenlabel">Lohn Min.</span>
                <input name="lohn_minuten" aria-label={`Lohnminuten der Position ${position.position_nr}`} type="number" step="1" min="0" className="feld zahl"
                  defaultValue={String(position.lohn_minuten)} />
              </label>
            </div>
          </details>
        </>
      )}
    </form>
  );
}

function GesperrteListe({ positionen }: { positionen: Position[] }) {
  return (
    <div className="gestapelt">
      {positionen.map((p) =>
        !rechnetMit(p.art) ? (
          <p key={p.id} className={p.art === "titel" ? "titelzeile" : "zusatz"}>
            {p.bezeichnung}
          </p>
        ) : (
          <div key={p.id} className="karte listenzeile">
            <span>
              <span className="zahl positionsnummer">{p.position_nr}</span>{" "}
              <span className="zeilentitel">{p.bezeichnung}</span>
              <br />
              <span className="zusatz">
                {String(p.menge)} {p.einheit} × {alsEuro(p.einzelpreis)}
                {Number(p.rabatt_prozent) > 0 ? ` − ${p.rabatt_prozent} %` : ""}
              </span>
            </span>
            <span className="zahl">{alsEuro(p.gesamt)}</span>
          </div>
        ),
      )}
    </div>
  );
}
