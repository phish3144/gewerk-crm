// Ein Ort fuer die Verbindungsdaten, damit ein fehlender Wert beim Start
// auffaellt und nicht erst beim ersten Datenzugriff als "fetch failed".
function pflicht(name: string, wert: string | undefined): string {
  if (!wert || wert.length === 0) {
    throw new Error(
      `${name} fehlt. Die Datei web/.env.local anlegen — Vorlage steht in web/.env.example.`,
    );
  }
  return wert;
}

export const umgebung = {
  supabaseUrl: pflicht("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL),
  supabaseSchluessel: pflicht(
    "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  ),
} as const;
