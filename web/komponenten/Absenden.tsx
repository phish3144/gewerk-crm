"use client";

import { useFormStatus } from "react-dom";

// Ein Knopf, der waehrend des Absendens sperrt und sagt, dass etwas laeuft.
// Ohne das drueckt man auf der Baustelle zweimal.
export function Absenden({
  children,
  laeuft = "Einen Moment …",
  art = "taste-primaer",
}: {
  children: React.ReactNode;
  laeuft?: string;
  art?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" className={`taste ${art}`} disabled={pending} aria-busy={pending}>
      {pending ? laeuft : children}
    </button>
  );
}
