import type { ReactNode } from "react";

// Ein beschriftetes Eingabefeld mit Platz für einen Fehler. Der Fehler steht am
// Feld, nicht in einem Kasten weit oben — sonst sucht man ihn.
export function Feld({
  name,
  label,
  fehler,
  hinweis,
  children,
  ...rest
}: {
  name: string;
  label: string;
  fehler?: string;
  hinweis?: string;
  children?: ReactNode;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const fehlerId = fehler ? `${name}-fehler` : undefined;
  const hinweisId = hinweis ? `${name}-hinweis` : undefined;

  return (
    <div className="eingabe">
      <label htmlFor={name}>{label}</label>
      {children ?? (
        <input
          id={name}
          name={name}
          className="feld"
          aria-invalid={fehler ? true : undefined}
          aria-describedby={[fehlerId, hinweisId].filter(Boolean).join(" ") || undefined}
          {...rest}
        />
      )}
      {hinweis && (
        <p className="zusatz" id={hinweisId}>
          {hinweis}
        </p>
      )}
      {fehler && (
        <p className="feldfehler" id={fehlerId} role="alert">
          {fehler}
        </p>
      )}
    </div>
  );
}
