"use client";

import { anstellen } from "@/lib/warteschlange";

// Der Nachweis zu einer Buchung ohne Position.
//
// Seit Migration 0020 laesst die Datenbank eine Zeitbuchung oder eine
// Materialentnahme ohne Position nur mit Nachweis zu. Der Nachweis ist eine
// gewoehnliche Zeile in dokumentation - Notiz oder Foto - und die Buchung
// verweist darauf.
//
// Reihenfolge ist hier alles: die Warteschlange sendet in der Reihenfolge, in
// der erfasst wurde, und bricht beim ersten Fehler ab. Der Nachweis muss also
// VOR der Buchung angestellt werden, sonst laeuft die Buchung beim Server in
// den Fremdschluessel. Deshalb gibt diese Funktion die Kennung zurueck, statt
// dass die Aufruferin sie selbst erzeugt.
export async function nachweisAnstellen(auftrag: {
  projektId: string;
  mitarbeiterId: string;
  text: string;
  foto?: { blob: Blob; name: string } | null;
}): Promise<string> {
  const id = crypto.randomUUID();
  await anstellen(
    "dokumentation",
    {
      id,
      projekt_id: auftrag.projektId,
      art: auftrag.foto ? "foto" : "notiz",
      text: auftrag.text.trim() || null,
      erfasst_am: new Date().toISOString(),
      erfasst_von: auftrag.mitarbeiterId,
    },
    auftrag.foto ?? undefined,
  );
  return id;
}

// Was als Nachweis durchgeht. Bewusst niedrig: zehn Sekunden auf der
// Baustelle, nicht ein Aufsatz. "Mehr" waere der sichere Weg, dass gar nichts
// erfasst wird - und dann meldet der Waechter nichts mehr.
export const NACHWEIS_MINDESTLAENGE = 5;

export function nachweisReicht(text: string, foto: unknown): boolean {
  return Boolean(foto) || text.trim().length >= NACHWEIS_MINDESTLAENGE;
}
