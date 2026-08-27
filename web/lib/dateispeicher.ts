import { getCloudflareContext } from "@opennextjs/cloudflare";

// Zugriff auf den R2-Bucket - und zwar so, dass sein Fehlen kein Absturz ist.
//
// Die Bindung gibt es nur in der workerd-Laufzeit. Unter `next start` wirft
// getCloudflareContext() sogar selbst, statt eine leere Umgebung zu liefern.
// Ein ungefangener Wurf wird daraus zu einem Serverfehler 500, und die
// Aufruferin kann nicht mehr unterscheiden, ob der Dateispeicher fehlt oder
// die Anfrage kaputt war.
//
// Deshalb hier einmal zentral: null heisst "kein Dateispeicher". Was ohne ihn
// noch geht, geht weiter - ein Schriftstueck ohne Fotos ist immer noch ein
// Schriftstueck.
export function dateispeicher(): R2Bucket | null {
  try {
    const { env } = getCloudflareContext();
    return (env as unknown as { DOKUMENTE?: R2Bucket }).DOKUMENTE ?? null;
  } catch {
    return null;
  }
}
