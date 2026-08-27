// Ergebnis einer Server Action. Getrennt nach: was oben steht (fehler) und was
// an einem einzelnen Feld steht (feldFehler).
export type Ergebnis = {
  fehler?: string;
  feldFehler?: Record<string, string>;
  // Was gut gegangen ist. Ohne diese Rueckmeldung sieht eine erfolgreiche
  // Aktion aus wie gar keine - die Nutzerin drueckt noch einmal.
  hinweis?: string;
};

type PostgresFehler = { code?: string; message?: string; details?: string };

// Ein Verstoss gegen eine Eindeutigkeit gehoert an das Feld, das ihn ausgeloest
// hat — nicht in einen roten Kasten mit dem Namen eines Datenbank-Constraints.
// Die Zuordnung steht ausgeschrieben, damit sie nachlesbar ist.
const eindeutigkeitZuFeld: Record<string, { feld: string; text: string }> = {
  kunde_betrieb_id_nummer_key: {
    feld: "nummer",
    text: "Diese Kundennummer ist schon vergeben.",
  },
  projekt_betrieb_id_nummer_key: {
    feld: "nummer",
    text: "Diese Projektnummer ist schon vergeben.",
  },
  artikel_betrieb_id_nummer_key: {
    feld: "nummer",
    text: "Diese Artikelnummer ist schon vergeben.",
  },
};

export function alsFeldfehler(fehler: unknown): Ergebnis | null {
  const f = fehler as PostgresFehler | null;
  if (!f || f.code !== "23505") return null;

  const text = `${f.message ?? ""} ${f.details ?? ""}`;
  for (const [constraint, ziel] of Object.entries(eindeutigkeitZuFeld)) {
    if (text.includes(constraint)) {
      return { feldFehler: { [ziel.feld]: ziel.text } };
    }
  }
  return null;
}
