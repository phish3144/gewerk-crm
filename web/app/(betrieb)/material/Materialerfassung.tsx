"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { anstellen } from "@/lib/warteschlange";
import { nachweisAnstellen, nachweisReicht } from "@/lib/nachweis";
import { Nachweis, LEERER_NACHWEIS, type NachweisStand } from "@/komponenten/Nachweis";
import { warteschlangeGeaendert } from "@/komponenten/Warteschlange";

type Position = { id: string; nr: number; text: string; einheit: string };
type Projekt = { id: string; text: string; positionen: Position[] };
type Artikel = { id: string; text: string; name: string; einheit: string; ek: number };

// Der zweite Erfassungspunkt des Waechters, nach demselben Muster wie die
// Zeiterfassung: die Positionsauswahl und "Keine passende Position" stehen
// gleichwertig nebeneinander. Waere der Ausweg umstaendlicher, wuerde
// irgendeine Position gewaehlt - und der Waechter bekaeme nie etwas zu sehen.
export function Materialerfassung({
  mitarbeiterId,
  projekte,
  artikel,
}: {
  mitarbeiterId: string;
  projekte: Projekt[];
  artikel: Artikel[];
}) {
  const router = useRouter();
  const [projektId, setzeProjektId] = useState("");
  const [artikelId, setzeArtikelId] = useState("");
  const [bezeichnung, setzeBezeichnung] = useState("");
  const [menge, setzeMenge] = useState("1");
  const [einheit, setzeEinheit] = useState("Stk");
  const [positionId, setzePositionId] = useState("");
  const [nachweis, setzeNachweis] = useState<NachweisStand>(LEERER_NACHWEIS);
  const [fehler, setzeFehler] = useState("");
  const [laeuft, setzeLaeuft] = useState(false);

  const projekt = projekte.find((p) => p.id === projektId) ?? null;
  const gewaehlt = artikel.find((a) => a.id === artikelId) ?? null;
  const ohnePosition = positionId === "";

  function artikelWaehlen(id: string) {
    setzeArtikelId(id);
    const a = artikel.find((x) => x.id === id);
    if (a) {
      setzeEinheit(a.einheit);
      setzeBezeichnung("");
    }
  }

  async function buchen() {
    const zahl = Number(menge.replace(",", "."));
    if (!projekt) {
      setzeFehler("Bitte zuerst die Baustelle wählen.");
      return;
    }
    if (!Number.isFinite(zahl) || zahl <= 0) {
      setzeFehler("Die Menge muss größer als null sein.");
      return;
    }
    // Die Benennung, die in die Buchung wandert: aus dem Stammsatz, wenn einer
    // gewaehlt ist, sonst die freie Eingabe.
    const benannt = (gewaehlt ? gewaehlt.name : bezeichnung).trim();
    if (benannt === "") {
      setzeFehler("Bitte einen Artikel wählen oder eine Bezeichnung eintragen.");
      return;
    }
    if (ohnePosition && !nachweisReicht(nachweis.text, nachweis.foto)) {
      setzeFehler("Ohne Position braucht die Entnahme eine Notiz oder ein Foto.");
      return;
    }

    setzeFehler("");
    setzeLaeuft(true);
    try {
      // Erst der Nachweis, dann die Buchung: die Warteschlange sendet in
      // dieser Reihenfolge, und die Buchung verweist auf den Nachweis.
      const nachweisId = ohnePosition
        ? await nachweisAnstellen({
            projektId: projekt.id,
            mitarbeiterId,
            text: nachweis.text,
            foto: nachweis.foto,
          })
        : null;

      await anstellen("materialentnahme", {
        id: crypto.randomUUID(),
        projekt_id: projekt.id,
        artikel_id: artikelId || null,
        // Die Bezeichnung wandert mit, genau wie der Einkaufspreis. Ein Artikel
        // wird umbenannt oder ausgelistet; was am 12. Maerz verbraucht wurde,
        // aendert sich dadurch nicht — und ohne diese Kopie waere ein einmal
        // gebuchter Artikel nie wieder loeschbar.
        bezeichnung: benannt,
        menge: zahl,
        einheit,
        // Der Einkaufspreis wandert mit. Der Stammpreis aendert sich, der Wert
        // dieser Entnahme nicht.
        ek_preis: gewaehlt?.ek ?? 0,
        position_id: positionId || null,
        nachweis_id: nachweisId,
        erfasst_am: new Date().toISOString(),
        erfasst_von: mitarbeiterId,
      });

      warteschlangeGeaendert();
      setzeArtikelId("");
      setzeBezeichnung("");
      setzeMenge("1");
      setzeNachweis(LEERER_NACHWEIS);
      if (navigator.onLine) router.refresh();
    } catch (f) {
      setzeFehler(f instanceof Error ? f.message : "Unbekannter Fehler.");
    } finally {
      setzeLaeuft(false);
    }
  }

  if (projekte.length === 0) {
    return (
      <div className="karte">
        <p className="zusatz">
          Kein Projekt im Zustand „geplant" oder „laufend". Material wird auf Projekte gebucht.
        </p>
      </div>
    );
  }

  return (
    <>
      <div className="karte gestapelt">
        <h2 className="kartentitel">Material buchen</h2>

        {fehler && (
          <p className="hinweis" role="alert">
            {fehler}
          </p>
        )}

        <label className="eingabe">
          <span>Baustelle</span>
          <select
            className="feld"
            value={projektId}
            onChange={(e) => {
              setzeProjektId(e.target.value);
              setzePositionId("");
            }}
          >
            <option value="">Bitte wählen</option>
            {projekte.map((p) => (
              <option key={p.id} value={p.id}>
                {p.text}
              </option>
            ))}
          </select>
        </label>

        {projekt && (
          <>
            <label className="eingabe">
              <span>Artikel</span>
              <select
                className="feld"
                value={artikelId}
                onChange={(e) => artikelWaehlen(e.target.value)}
              >
                <option value="">Nicht im Stamm — frei eintragen</option>
                {artikel.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.text}
                  </option>
                ))}
              </select>
            </label>

            {!gewaehlt && (
              <label className="eingabe">
                <span>Bezeichnung</span>
                <input
                  className="feld"
                  value={bezeichnung}
                  onChange={(e) => setzeBezeichnung(e.target.value)}
                  placeholder="z. B. Leerrohr M25"
                />
              </label>
            )}

            <div className="reihe" style={{ alignItems: "flex-end" }}>
              <label className="eingabe" style={{ width: "8rem" }}>
                <span>Menge</span>
                <input
                  className="feld zahl"
                  inputMode="decimal"
                  value={menge}
                  onChange={(e) => setzeMenge(e.target.value)}
                />
              </label>
              <label className="eingabe" style={{ width: "8rem" }}>
                <span>Einheit</span>
                <input
                  className="feld"
                  value={einheit}
                  onChange={(e) => setzeEinheit(e.target.value)}
                />
              </label>
            </div>

            <label className="eingabe">
              <span>Position</span>
              <select
                className="feld"
                value={positionId}
                onChange={(e) => setzePositionId(e.target.value)}
              >
                <option value="">Keine passende Position</option>
                {projekt.positionen.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.nr} · {p.text} ({p.einheit})
                  </option>
                ))}
              </select>
            </label>

            {projekt.positionen.length === 0 && (
              <p className="zusatz">
                Für diese Baustelle gibt es noch keinen festgeschriebenen Auftrag — jede Entnahme
                geht deshalb als ungeklärt ins Büro.
              </p>
            )}

            {ohnePosition && <Nachweis stand={nachweis} beiAenderung={setzeNachweis} beschriftung="Wofür wurde das gebraucht?" />}

            <button
              type="button"
              className="taste taste-primaer taste-baustelle"
              onClick={buchen}
              disabled={laeuft}
            >
              {laeuft ? "Einen Moment …" : "Entnahme buchen"}
            </button>
          </>
        )}
      </div>
    </>
  );
}
