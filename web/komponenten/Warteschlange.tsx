"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { absenden, offen } from "@/lib/warteschlange";

// Der Zustand wird angezeigt, nicht verschwiegen. Eine stille Warteschlange ist
// der haeufigste Vertrauensbruch mobiler Baustellen-Apps: die Monteurin erfasst
// zwanzig Stunden, sieht keinen Hinweis, und im Buero fehlt alles.
export function Warteschlange({ beiAenderung }: { beiAenderung?: (anzahl: number) => void }) {
  const router = useRouter();
  const [wartend, setzeWartend] = useState(0);
  const [laeuft, setzeLaeuft] = useState(false);
  const [online, setzeOnline] = useState(true);

  const pruefen = useCallback(async () => {
    const liste = await offen();
    setzeWartend(liste.length);
    beiAenderung?.(liste.length);
  }, [beiAenderung]);

  const senden = useCallback(async () => {
    if (laeuft) return;
    setzeLaeuft(true);
    try {
      const { gesendet } = await absenden();
      // Angekommenes gehoert auf den Bildschirm. Ohne dieses Neuladen bleibt
      // die Liste leer, bis die Nutzerin von sich aus neu laedt — und die
      // gerade erfasste Stunde sieht aus wie verloren.
      if (gesendet > 0 && navigator.onLine) router.refresh();
    } finally {
      setzeLaeuft(false);
      await pruefen();
    }
  }, [laeuft, pruefen, router]);

  useEffect(() => {
    setzeOnline(navigator.onLine);
    void pruefen();

    const wiederDa = () => {
      setzeOnline(true);
      void senden();
    };
    const weg = () => setzeOnline(false);

    // Neu angestellt: sofort versuchen, wenn Netz da ist. Ohne das laege ein
    // Eintrag bis zum naechsten Appstart in der Warteschlange — auch bei bestem
    // Empfang.
    const angestellt = () => {
      void pruefen();
      if (navigator.onLine) void senden();
    };

    window.addEventListener("online", wiederDa);
    window.addEventListener("offline", weg);
    window.addEventListener("gewerk:warteschlange", angestellt);

    // Beim Start einmal versuchen: die App wurde vielleicht im Funkloch
    // geschlossen und im Buero wieder geoeffnet.
    if (navigator.onLine) void senden();

    return () => {
      window.removeEventListener("online", wiederDa);
      window.removeEventListener("offline", weg);
      window.removeEventListener("gewerk:warteschlange", angestellt);
    };
    // Absichtlich nur beim Aufbau: die Ereignisse halten den Stand aktuell.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (wartend === 0 && online) return null;

  return (
    <div className="offline" role="status" data-warteschlange={wartend}>
      <span aria-hidden="true">{online ? "↑" : "⚡"}</span>
      <span>
        {!online && "Kein Netz. "}
        {wartend === 0
          ? "Alles übertragen."
          : `${wartend} ${wartend === 1 ? "Eintrag wartet" : "Einträge warten"} auf Übertragung.`}
      </span>
      {online && wartend > 0 && (
        <button type="button" className="taste taste-sekundaer" onClick={senden} disabled={laeuft}>
          {laeuft ? "Überträgt …" : "Jetzt übertragen"}
        </button>
      )}
    </div>
  );
}

// Sagt der Anzeige, dass sich etwas geaendert hat, ohne dass beide Komponenten
// voneinander wissen muessen.
export function warteschlangeGeaendert() {
  window.dispatchEvent(new Event("gewerk:warteschlange"));
}
