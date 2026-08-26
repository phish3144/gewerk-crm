"use client";

import Link from "next/link";
import { useActionState, useState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { Feld } from "@/komponenten/Feld";
import { Abbruch } from "@/komponenten/Zustand";
import type { Ergebnis } from "@/lib/formular";

export function BelegAnlegenFormular({
  aktion,
  kunden,
  projekte,
}: {
  aktion: (vorher: Ergebnis, daten: FormData) => Promise<Ergebnis>;
  kunden: { id: string; name: string }[];
  projekte: { id: string; bezeichnung: string; kunde_id: string }[];
}) {
  const [ergebnis, absenden] = useActionState<Ergebnis, FormData>(aktion, {});
  const [kunde, setzeKunde] = useState("");
  const f = (name: string) => ergebnis.feldFehler?.[name];

  // Nur Projekte des gewaehlten Kunden anbieten. Ein Beleg, der auf ein Projekt
  // eines anderen Kunden zeigt, waere fachlich falsch — die Datenbank haelt das
  // nicht auf, weil beide zum selben Betrieb gehoeren.
  const passende = kunde ? projekte.filter((p) => p.kunde_id === kunde) : [];

  return (
    <form action={absenden} className="formular">
      <input type="hidden" name="art" value="angebot" />
      {ergebnis.fehler && <Abbruch>{ergebnis.fehler}</Abbruch>}

      <Feld name="kunde_id" label="Kunde" fehler={f("kunde_id")}>
        <select
          id="kunde_id"
          name="kunde_id"
          className="feld"
          required
          value={kunde}
          onChange={(e) => setzeKunde(e.target.value)}
        >
          <option value="" disabled>
            Bitte wählen
          </option>
          {kunden.map((k) => (
            <option key={k.id} value={k.id}>
              {k.name}
            </option>
          ))}
        </select>
      </Feld>

      <Feld
        name="projekt_id"
        label="Projekt"
        fehler={f("projekt_id")}
        hinweis={
          kunde && passende.length === 0
            ? "Zu diesem Kunden gibt es noch kein Projekt. Das ist in Ordnung."
            : "Optional."
        }
      >
        <select id="projekt_id" name="projekt_id" className="feld" disabled={!kunde}>
          <option value="">Ohne Projekt</option>
          {passende.map((p) => (
            <option key={p.id} value={p.id}>
              {p.bezeichnung}
            </option>
          ))}
        </select>
      </Feld>

      <Feld
        name="betreff"
        label="Betreff"
        fehler={f("betreff")}
        placeholder="z. B. Sanierung Bad Erdgeschoss"
      />

      <div className="reihe">
        <Absenden laeuft="Wird angelegt …">Weiter zu den Positionen</Absenden>
        <Link className="taste taste-sekundaer" href="/belege">
          Abbrechen
        </Link>
      </div>
    </form>
  );
}
