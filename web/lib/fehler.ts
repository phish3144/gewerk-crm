// Die Datenbank spricht Deutsch. Alle Abbrueche aus Triggern und Funktionen
// tragen bereits verstaendliche Meldungen ("Beleg X ist bereits festgeschrieben"),
// deshalb werden sie durchgereicht statt ersetzt.
//
// Uebersetzt wird nur, was Postgres selbst formuliert — das sind die Faelle, in
// denen sonst englischer Fachjargon in der Oberflaeche steht.
type PostgresFehler = { code?: string; message?: string; details?: string };

const nachCode: Record<string, string> = {
  "23505": "Diesen Eintrag gibt es bereits.",
  "23503": "Ein verknuepfter Datensatz fehlt oder wird noch verwendet.",
  "23514": "Die Eingabe verletzt eine Regel des Datensatzes.",
  "23502": "Ein Pflichtfeld ist leer.",
  "42501": "Dafuer fehlt die Berechtigung.",
  "P0002": "Nicht gefunden.",
  "2F004": "Dafuer fehlt die Berechtigung.",
};

// Postgres-Meldungen, die in der Oberflaeche nichts verloren haben.
const technisch = [
  /new row violates row-level security policy/i,
  /permission denied for/i,
  /duplicate key value violates unique constraint/i,
  /violates foreign key constraint/i,
  /violates check constraint/i,
];

export function fehlertext(fehler: unknown): string {
  const f = fehler as PostgresFehler | null;
  if (!f) return "Unbekannter Fehler.";

  const meldung = f.message ?? "";

  // Eigene Abbrueche aus Triggern und Funktionen sind bereits fuer Menschen
  // geschrieben und kommen unveraendert durch.
  const istTechnisch = technisch.some((m) => m.test(meldung));
  if (meldung && !istTechnisch) return meldung;

  const bekannt = f.code ? nachCode[f.code] : undefined;
  if (bekannt) return bekannt;
  if (istTechnisch) return "Dafuer fehlt die Berechtigung.";
  return meldung || "Unbekannter Fehler.";
}
