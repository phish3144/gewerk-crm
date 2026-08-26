import Link from "next/link";
import type { ReactNode } from "react";

// Ein leerer Bestand ist kein Fehler, sondern der Anfang. Er sagt, was als
// Naechstes zu tun ist, statt nur "keine Daten" zu melden.
export function Leer({
  titel,
  text,
  aktion,
}: {
  titel: string;
  text: string;
  aktion?: { pfad: string; text: string };
}) {
  return (
    <div className="karte gestapelt" style={{ textAlign: "center" }}>
      <p className="kartentitel">{titel}</p>
      <p className="zusatz">{text}</p>
      {aktion && (
        <div>
          <Link className="taste taste-primaer" href={aktion.pfad}>
            {aktion.text}
          </Link>
        </div>
      )}
    </div>
  );
}

// Ein Abbruch wird angezeigt, nicht verschluckt.
export function Abbruch({ children }: { children: ReactNode }) {
  return (
    <p className="hinweis" role="alert">
      {children}
    </p>
  );
}
