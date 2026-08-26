"use client";

import { useCallback, useEffect, useState } from "react";
import { offen } from "@/lib/warteschlange";
import { alsDatum } from "@/lib/geld";

export type Zeile = {
  id: string;
  projekt: string;
  beginn: string;
  ende: string | null;
  pause: number;
  taetigkeit: string | null;
  zugeordnet: boolean;
};

// Zeigt, was in der Datenbank steht — und was noch auf dem Geraet wartet.
//
// Ohne den zweiten Teil verschwindet eine gerade erfasste Stunde aus der
// Ansicht, bis sie uebertragen ist. Auf der Baustelle sieht das aus wie
// verloren, und beim naechsten Mal schreibt die Monteurin wieder auf Papier.
export function ErfassteZeiten({
  gespeichert,
  projektNamen,
}: {
  gespeichert: Zeile[];
  projektNamen: Record<string, string>;
}) {
  const [wartend, setzeWartend] = useState<Zeile[]>([]);

  const lesen = useCallback(async () => {
    const liste = await offen();
    setzeWartend(
      liste
        .filter((e) => e.art === "zeiteintrag")
        .map((e) => {
          const n = e.nutzlast as Record<string, unknown>;
          return {
            id: String(n["id"]),
            projekt: projektNamen[String(n["projekt_id"])] ?? "Baustelle",
            beginn: String(n["beginn"]),
            ende: n["ende"] ? String(n["ende"]) : null,
            pause: Number(n["pause_minuten"] ?? 0),
            taetigkeit: n["taetigkeit"] ? String(n["taetigkeit"]) : null,
            zugeordnet: Boolean(n["position_id"]),
          };
        }),
    );
  }, [projektNamen]);

  useEffect(() => {
    void lesen();
    const bei = () => void lesen();
    window.addEventListener("gewerk:warteschlange", bei);
    const takt = setInterval(bei, 2000);
    return () => {
      window.removeEventListener("gewerk:warteschlange", bei);
      clearInterval(takt);
    };
  }, [lesen]);

  // Was schon in der Datenbank steht, nicht doppelt zeigen.
  const bekannt = new Set(gespeichert.map((z) => z.id));
  const nurWartend = wartend.filter((z) => !bekannt.has(z.id));
  const alle = [...nurWartend, ...gespeichert];

  if (alle.length === 0) return <p className="zusatz">Noch nichts erfasst.</p>;

  return (
    <>
      {alle.map((z) => {
        const dauer = z.ende
          ? (new Date(z.ende).getTime() - new Date(z.beginn).getTime()) / 36e5 - z.pause / 60
          : null;
        const wartet = nurWartend.some((w) => w.id === z.id);
        return (
          <div key={z.id} className="listenzeile">
            <span>
              <span className="zeilentitel">{z.projekt}</span>
              <br />
              <span className="zusatz">
                {alsDatum(z.beginn)} · {z.taetigkeit ?? "ohne Angabe"}
                {!z.zugeordnet && " · noch nicht zugeordnet"}
              </span>
            </span>
            <span className="reihe">
              {wartet && <span className="abzeichen abzeichen-wartet">wartet</span>}
              <span className="zahl">
                {dauer === null ? "läuft" : `${dauer.toFixed(2).replace(".", ",")} h`}
              </span>
            </span>
          </div>
        );
      })}
    </>
  );
}
