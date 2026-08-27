"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { anstellen } from "@/lib/warteschlange";
import { nachweisAnstellen, nachweisReicht } from "@/lib/nachweis";
import { Nachweis, LEERER_NACHWEIS, type NachweisStand } from "@/komponenten/Nachweis";
import { warteschlangeGeaendert } from "@/komponenten/Warteschlange";

type Position = { id: string; nr: number; text: string; einheit: string };
type Projekt = { id: string; text: string; positionen: Position[] };

// Der Erfassungspunkt, an dem der Nachtragswaechter spaeter ansetzt.
//
// "Keine passende Position" ist ein gleichwertiger, sichtbarer Knopf neben der
// Liste — kein versteckter Notausgang. Wer ihn drueckt, hat nichts falsch
// gemacht; er meldet nur, dass das Leistungsverzeichnis die Arbeit nicht
// abdeckt. Waere er umstaendlicher als die Positionsauswahl, wuerden die
// Monteure irgendeine Position waehlen, und der Waechter verhungerte.
export function Zeiterfassung({
  mitarbeiterId,
  projekte,
}: {
  mitarbeiterId: string;
  projekte: Projekt[];
}) {
  const router = useRouter();
  const [projekt, setzeProjekt] = useState<Projekt | null>(null);
  const [laeuft, setzeLaeuft] = useState<{ beginn: string; position: string | null } | null>(null);
  const [nachtragen, setzeNachtragen] = useState(false);

  async function starten(positionId: string | null) {
    setzeLaeuft({ beginn: new Date().toISOString(), position: positionId });
  }

  async function stoppen(taetigkeit: string, nachweis: NachweisStand) {
    if (!laeuft || !projekt) return;

    // Ohne Position zuerst den Nachweis anstellen, dann die Buchung mit dem
    // Verweis darauf. Die Warteschlange sendet in dieser Reihenfolge; anders
    // herum liefe die Buchung beim Server in den Fremdschluessel.
    const nachweisId = laeuft.position
      ? null
      : await nachweisAnstellen({
          projektId: projekt.id,
          mitarbeiterId,
          text: nachweis.text,
          foto: nachweis.foto,
        });

    await anstellen("zeiteintrag", {
      id: crypto.randomUUID(),
      projekt_id: projekt.id,
      mitarbeiter_id: mitarbeiterId,
      beginn: laeuft.beginn,
      ende: new Date().toISOString(),
      pause_minuten: 0,
      taetigkeit: laeuft.position ? taetigkeit : nachweis.text,
      position_id: laeuft.position,
      nachweis_id: nachweisId,
    });
    warteschlangeGeaendert();
    setzeLaeuft(null);
    // Nur mit Netz neu laden. Im Funkloch wirft router.refresh() die Seite auf
    // die Fehlerseite des Browsers — der Monteur drueckt Stopp und sieht "Keine
    // Internetverbindung", obwohl der Eintrag sicher in der Warteschlange
    // liegt. Die Liste zeigt wartende Eintraege ohnehin selbst an.
    if (navigator.onLine) router.refresh();
  }

  if (projekte.length === 0) {
    return (
      <div className="karte">
        <p className="zusatz">
          Kein Projekt im Zustand „geplant" oder „laufend". Zeiten werden auf Projekte gebucht.
        </p>
      </div>
    );
  }

  return (
    <>
      {laeuft && projekt ? (
        <LaufendeZeit
          projekt={projekt}
          beginn={laeuft.beginn}
          ohnePosition={laeuft.position === null}
          beiStopp={stoppen}
        />
      ) : (
        <div className="karte gestapelt">
          <h2 className="kartentitel">Zeit erfassen</h2>

          <label className="eingabe">
            <span>Baustelle</span>
            <select
              className="feld"
              value={projekt?.id ?? ""}
              onChange={(e) =>
                setzeProjekt(projekte.find((p) => p.id === e.target.value) ?? null)
              }
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
              <p className="gruppenlabel">Woran arbeiten Sie?</p>

              <div className="gestapelt">
                {projekt.positionen.map((p) => (
                  <button
                    key={p.id}
                    type="button"
                    className="taste taste-sekundaer positionswahl"
                    onClick={() => starten(p.id)}
                  >
                    <span className="zahl positionsnummer">{p.nr}</span>
                    <span>{p.text}</span>
                  </button>
                ))}

                {projekt.positionen.length === 0 && (
                  <p className="zusatz">
                    Für diese Baustelle gibt es noch keinen festgeschriebenen Auftrag.
                  </p>
                )}

                {/* Gleichwertig, gleich gross, gleich sichtbar. */}
                <button
                  type="button"
                  className="taste taste-sekundaer positionswahl ungeklaert"
                  onClick={() => starten(null)}
                >
                  <span aria-hidden="true">?</span>
                  <span>
                    <strong>Keine passende Position</strong>
                    <br />
                    <span className="zusatz">
                      Das Büro klärt, ob daraus ein Nachtrag wird.
                    </span>
                  </span>
                </button>
              </div>

              <button
                type="button"
                className="taste taste-sekundaer"
                onClick={() => setzeNachtragen((n) => !n)}
              >
                {nachtragen ? "Nachtrag schließen" : "Vergangenen Tag nachtragen"}
              </button>

              {nachtragen && (
                <Nachtragen
                  projekt={projekt}
                  mitarbeiterId={mitarbeiterId}
                  beiFertig={() => {
                    setzeNachtragen(false);
                    if (navigator.onLine) router.refresh();
                  }}
                />
              )}
            </>
          )}
        </div>
      )}
    </>
  );
}

function LaufendeZeit({
  projekt,
  beginn,
  ohnePosition,
  beiStopp,
}: {
  projekt: Projekt;
  beginn: string;
  ohnePosition: boolean;
  beiStopp: (taetigkeit: string, nachweis: NachweisStand) => void;
}) {
  const [taetigkeit, setzeTaetigkeit] = useState("");
  const [nachweis, setzeNachweis] = useState<NachweisStand>(LEERER_NACHWEIS);
  const seit = new Date(beginn).toLocaleTimeString("de-DE", { hour: "2-digit", minute: "2-digit" });

  // Ohne Position ist die Notiz aus dem Nachweisblock die Taetigkeit - zweimal
  // dasselbe eintippen wuerde niemand.
  const fertig = ohnePosition ? nachweisReicht(nachweis.text, nachweis.foto) : true;

  return (
    <div className="karte gestapelt">
      <h2 className="kartentitel">Läuft seit {seit}</h2>
      <p className="zusatz">
        {projekt.text}
        {ohnePosition && " · keine passende Position"}
      </p>

      {!ohnePosition && (
        <label className="eingabe">
          <span>Was wurde gemacht?</span>
          <input
            className="feld"
            value={taetigkeit}
            onChange={(e) => setzeTaetigkeit(e.target.value)}
            placeholder="z. B. Rohinstallation Bad"
          />
        </label>
      )}

      {ohnePosition && <Nachweis stand={nachweis} beiAenderung={setzeNachweis} />}

      <button
        type="button"
        className="taste taste-primaer taste-baustelle"
        onClick={() => beiStopp(taetigkeit, nachweis)}
        disabled={!fertig}
      >
        Stopp
      </button>
    </div>
  );
}

// § 17 MiLoG laesst im Baugewerbe sieben Kalendertage Zeit fuer die
// Aufzeichnung. Ohne Nachtrag muesste jede vergessene Stunde verfallen.
function Nachtragen({
  projekt,
  mitarbeiterId,
  beiFertig,
}: {
  projekt: Projekt;
  mitarbeiterId: string;
  beiFertig: () => void;
}) {
  const heute = new Date().toISOString().slice(0, 10);
  const [tag, setzeTag] = useState(heute);
  const [von, setzeVon] = useState("07:00");
  const [bis, setzeBis] = useState("16:00");
  const [pause, setzePause] = useState("30");
  const [taetigkeit, setzeTaetigkeit] = useState("");
  const [position, setzePosition] = useState("");
  const [nachweis, setzeNachweis] = useState<NachweisStand>(LEERER_NACHWEIS);
  const [fehler, setzeFehler] = useState("");

  const frueheste = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10);
  const ohnePosition = position === "";

  // Ohne Position ist die Notiz aus dem Nachweisblock die Taetigkeit. Zwei
  // Felder fuer dasselbe waeren nicht nur laestig — man fuellt eins aus, das
  // andere bleibt leer, und hinterher steht in der Akte das Falsche.
  const fertig = ohnePosition ? nachweisReicht(nachweis.text, nachweis.foto) : true;

  async function speichern() {
    if (bis <= von) {
      setzeFehler("Das Ende muss nach dem Beginn liegen.");
      return;
    }
    setzeFehler("");

    const nachweisId = ohnePosition
      ? await nachweisAnstellen({
          projektId: projekt.id,
          mitarbeiterId,
          text: nachweis.text,
          foto: nachweis.foto,
        })
      : null;

    await anstellen("zeiteintrag", {
      id: crypto.randomUUID(),
      projekt_id: projekt.id,
      mitarbeiter_id: mitarbeiterId,
      beginn: new Date(`${tag}T${von}`).toISOString(),
      ende: new Date(`${tag}T${bis}`).toISOString(),
      pause_minuten: Number(pause) || 0,
      taetigkeit: ohnePosition ? nachweis.text : taetigkeit,
      position_id: position || null,
      nachweis_id: nachweisId,
    });
    warteschlangeGeaendert();
    beiFertig();
  }


  return (
    <div className="gestapelt">
      {fehler && (
        <p className="hinweis" role="alert">
          {fehler}
        </p>
      )}
      <div className="reihe" style={{ alignItems: "flex-end" }}>
        <label className="eingabe" style={{ width: "10rem" }}>
          <span>Tag</span>
          <input type="date" className="feld" value={tag} min={frueheste} max={heute}
            onChange={(e) => setzeTag(e.target.value)} />
        </label>
        <label className="eingabe" style={{ width: "7rem" }}>
          <span>Von</span>
          <input type="time" className="feld" value={von} onChange={(e) => setzeVon(e.target.value)} />
        </label>
        <label className="eingabe" style={{ width: "7rem" }}>
          <span>Bis</span>
          <input type="time" className="feld" value={bis} onChange={(e) => setzeBis(e.target.value)} />
        </label>
        <label className="eingabe" style={{ width: "7rem" }}>
          <span>Pause (Min.)</span>
          <input type="number" min="0" className="feld zahl" value={pause}
            onChange={(e) => setzePause(e.target.value)} />
        </label>
      </div>
      <label className="eingabe">
        <span>Position</span>
        <select className="feld" value={position} onChange={(e) => setzePosition(e.target.value)}>
          <option value="">Keine passende Position</option>
          {projekt.positionen.map((p) => (
            <option key={p.id} value={p.id}>
              {p.nr} · {p.text}
            </option>
          ))}
        </select>
      </label>
      {!ohnePosition && (
        <label className="eingabe">
          <span>Tätigkeit</span>
          <input
            className="feld"
            value={taetigkeit}
            onChange={(e) => setzeTaetigkeit(e.target.value)}
          />
        </label>
      )}

      {ohnePosition && <Nachweis stand={nachweis} beiAenderung={setzeNachweis} />}

      <button
        type="button"
        className="taste taste-primaer"
        onClick={speichern}
        disabled={!fertig}
      >
        Nachtragen
      </button>
    </div>
  );
}
