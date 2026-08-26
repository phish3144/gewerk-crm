"use client";

import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { anstellen } from "@/lib/warteschlange";
import { Warteschlange, warteschlangeGeaendert } from "@/komponenten/Warteschlange";

// Fotos werden vor dem Anstellen verkleinert. Ein Handyfoto hat heute leicht
// 6 MB; auf der Baustelle sind das Minuten Funk und am Monatsende Geld.
// Zielgroesse rund 500 KB bei 1600 px Kante.
async function verkleinern(datei: File): Promise<Blob> {
  if (!datei.type.startsWith("image/")) return datei;
  try {
    const bild = await createImageBitmap(datei);
    const kante = 1600;
    const faktor = Math.min(1, kante / Math.max(bild.width, bild.height));
    const breite = Math.round(bild.width * faktor);
    const hoehe = Math.round(bild.height * faktor);

    const flaeche = new OffscreenCanvas(breite, hoehe);
    const stift = flaeche.getContext("2d");
    if (!stift) return datei;
    stift.drawImage(bild, 0, 0, breite, hoehe);
    return await flaeche.convertToBlob({ type: "image/jpeg", quality: 0.82 });
  } catch {
    // Kein OffscreenCanvas, kein createImageBitmap: dann eben im Original.
    return datei;
  }
}

export function Baustellendoku({
  projektId,
  mitarbeiterId,
}: {
  projektId: string;
  mitarbeiterId: string;
}) {
  const router = useRouter();
  const dateiwahl = useRef<HTMLInputElement>(null);
  const [notiz, setzeNotiz] = useState("");
  const [laeuft, setzeLaeuft] = useState(false);
  const [fehler, setzeFehler] = useState("");

  async function fotoAufnehmen(datei: File) {
    setzeLaeuft(true);
    setzeFehler("");
    try {
      const klein = await verkleinern(datei);

      // Das Bild geht mit in die Warteschlange, nicht sofort ans Netz. Im
      // Funkloch wartet es auf dem Geraet; sobald Empfang da ist, legt die
      // Warteschlange erst die Datei ab und schickt dann die Zeile.
      await anstellen(
        "dokumentation",
        {
          id: crypto.randomUUID(),
          projekt_id: projektId,
          art: "foto",
          text: notiz || null,
          erfasst_am: new Date().toISOString(),
          erfasst_von: mitarbeiterId,
        },
        { blob: klein, name: datei.name || "foto.jpg" },
      );
      warteschlangeGeaendert();
      setzeNotiz("");
      if (navigator.onLine) router.refresh();
    } catch (f) {
      setzeFehler(f instanceof Error ? f.message : "Unbekannter Fehler.");
    } finally {
      setzeLaeuft(false);
    }
  }

  async function notizSichern() {
    if (!notiz.trim()) return;
    setzeLaeuft(true);
    setzeFehler("");
    try {
      await anstellen("dokumentation", {
        id: crypto.randomUUID(),
        projekt_id: projektId,
        art: "notiz",
        text: notiz.trim(),
        erfasst_am: new Date().toISOString(),
        erfasst_von: mitarbeiterId,
      });
      warteschlangeGeaendert();
      setzeNotiz("");
      if (navigator.onLine) router.refresh();
    } catch (f) {
      setzeFehler(f instanceof Error ? f.message : "Unbekannter Fehler.");
    } finally {
      setzeLaeuft(false);
    }
  }

  return (
    <>
      <Warteschlange />
      <div className="karte gestapelt">
        {fehler && (
          <p className="hinweis" role="alert">
            {fehler}
          </p>
        )}

        <label className="eingabe">
          <span>Notiz</span>
          <textarea
            className="feld"
            rows={3}
            value={notiz}
            onChange={(e) => setzeNotiz(e.target.value)}
            placeholder="Was ist auf der Baustelle passiert?"
          />
        </label>

        <div className="reihe">
          <button
            type="button"
            className="taste taste-primaer"
            onClick={notizSichern}
            disabled={laeuft || notiz.trim() === ""}
          >
            Notiz speichern
          </button>

          <button
            type="button"
            className="taste taste-sekundaer"
            onClick={() => dateiwahl.current?.click()}
            disabled={laeuft}
          >
            {laeuft ? "Einen Moment …" : "Foto aufnehmen"}
          </button>
          <input
            ref={dateiwahl}
            type="file"
            accept="image/*"
            capture="environment"
            hidden
            aria-label="Foto aufnehmen"
            onChange={(e) => {
              const datei = e.target.files?.[0];
              if (datei) void fotoAufnehmen(datei);
              e.target.value = "";
            }}
          />
        </div>

        <p className="zusatz">
          Fotos werden vor dem Senden auf etwa 500 KB verkleinert. Ohne Netz warten Notiz und Foto
          auf dem Gerät und gehen raus, sobald wieder Empfang da ist.
        </p>
      </div>
    </>
  );
}
