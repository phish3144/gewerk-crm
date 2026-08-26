"use client";

import { useEffect, useState } from "react";

type Thema = "system" | "tag" | "nacht";
const SPEICHER = "gewerk_thema";

// Die Tokens kennen drei Zustaende: :root ist Tag, [data-theme="nacht"] ist
// Nacht, und ohne Attribut entscheidet prefers-color-scheme. Genau das bildet
// der Umschalter ab — "system" heisst, das Attribut wird entfernt.
export function ThemaUmschalter() {
  const [thema, setzeThema] = useState<Thema>("system");

  useEffect(() => {
    const gespeichert = localStorage.getItem(SPEICHER) as Thema | null;
    if (gespeichert) setzeThema(gespeichert);
  }, []);

  function wechseln() {
    const reihe: Thema[] = ["system", "tag", "nacht"];
    const naechstes = reihe[(reihe.indexOf(thema) + 1) % reihe.length] ?? "system";
    setzeThema(naechstes);
    try {
      if (naechstes === "system") {
        localStorage.removeItem(SPEICHER);
        document.documentElement.removeAttribute("data-theme");
      } else {
        localStorage.setItem(SPEICHER, naechstes);
        document.documentElement.setAttribute("data-theme", naechstes);
      }
    } catch {
      // Privates Fenster oder gesperrter Speicher: die Umschaltung gilt dann
      // nur fuer diese Sitzung. Kein Grund, die Seite scheitern zu lassen.
    }
  }

  const beschriftung =
    thema === "system" ? "Darstellung: Gerät" : thema === "tag" ? "Darstellung: Tag" : "Darstellung: Nacht";
  const symbol = thema === "system" ? "◐" : thema === "tag" ? "☀" : "☾";

  return (
    <button type="button" className="thema-taste" onClick={wechseln} title={beschriftung}>
      <span aria-hidden="true">{symbol}</span>
      <span className="sr-only">{beschriftung}</span>
    </button>
  );
}
