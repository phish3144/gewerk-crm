export const BELEG_ART_TEXT: Record<string, string> = {
  angebot: "Angebot",
  auftrag: "Auftrag",
  abschlagsrechnung: "Abschlagsrechnung",
  teilrechnung: "Teilrechnung",
  schlussrechnung: "Schlussrechnung",
  gutschrift: "Gutschrift",
  storno: "Storno",
};

export const POSITION_ART_TEXT: Record<string, string> = {
  leistung: "Leistung",
  material: "Material",
  lohn: "Lohn",
  fremdleistung: "Fremdleistung",
  text: "Text",
  titel: "Titel",
};

// Text- und Titelzeilen gliedern das Leistungsverzeichnis, sie rechnen nicht mit.
// beleg_festschreiben() zaehlt genau diese beiden nicht als abrechenbar.
export function rechnetMit(art: string): boolean {
  return art !== "text" && art !== "titel";
}

export const BELEG_STATUS_TEXT: Record<string, string> = {
  entwurf: "Entwurf",
  festgeschrieben: "Festgeschrieben",
  versendet: "Versendet",
  angenommen: "Angenommen",
  abgelehnt: "Abgelehnt",
  bezahlt: "Bezahlt",
  storniert: "Storniert",
};

export const BELEG_STATUS_ABZEICHEN: Record<string, string> = {
  entwurf: "abzeichen-wartet",
  festgeschrieben: "abzeichen",
  versendet: "abzeichen",
  angenommen: "abzeichen-erfolg",
  abgelehnt: "abzeichen-kritisch",
  bezahlt: "abzeichen-erfolg",
  storniert: "abzeichen-kritisch",
};

// Nur ein Entwurf ist aenderbar. Alles andere hat eine Nummer und ist nach GoBD
// eingefroren - die Datenbank setzt das mit Triggern durch, die Oberflaeche
// bietet es deshalb gar nicht erst an.
export function istEntwurf(status: string | null | undefined): boolean {
  return status === "entwurf";
}
