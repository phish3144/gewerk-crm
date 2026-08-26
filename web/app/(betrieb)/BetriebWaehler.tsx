"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import type { Zugehoerigkeit } from "@/lib/betrieb";

// Die Auswahl liegt in einem Keks, aber sie entscheidet nichts: lib/betrieb.ts
// prueft jeden Wert gegen die Liste aus der Datenbank und verwirft ihn, wenn er
// nicht vorkommt. Ein veraenderter Keks fuehrt damit nicht in einen fremden
// Betrieb, sondern zurueck zum ersten eigenen.
export function BetriebWaehler({ alle, aktiv }: { alle: Zugehoerigkeit[]; aktiv: string }) {
  const router = useRouter();
  const [laeuft, starte] = useTransition();

  return (
    <select
      className="feld"
      style={{ width: "auto" }}
      value={aktiv}
      disabled={laeuft}
      aria-label="Betrieb wechseln"
      onChange={(e) => {
        const gewaehlt = e.target.value;
        // 180 Tage: der Wechsel soll ein Gerät überdauern, nicht eine Sitzung.
        document.cookie = `gewerk_betrieb=${gewaehlt}; path=/; max-age=${60 * 60 * 24 * 180}; SameSite=Lax`;
        starte(() => router.refresh());
      }}
    >
      {alle.map((z) => (
        <option key={z.betrieb_id} value={z.betrieb_id}>
          {z.name}
        </option>
      ))}
    </select>
  );
}
