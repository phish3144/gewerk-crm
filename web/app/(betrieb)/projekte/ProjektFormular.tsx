"use client";

import Link from "next/link";
import { useActionState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { Feld } from "@/komponenten/Feld";
import { Abbruch } from "@/komponenten/Zustand";
import type { Ergebnis } from "@/lib/formular";

export type ProjektWerte = {
  id?: string;
  bezeichnung?: string | null;
  kunde_id?: string | null;
  nummer?: string | null;
  strasse?: string | null;
  plz?: string | null;
  ort?: string | null;
  status?: string | null;
  beginn?: string | null;
  ende?: string | null;
};

const ZUSTAENDE = [
  { wert: "geplant", text: "Geplant" },
  { wert: "laufend", text: "Laufend" },
  { wert: "abgeschlossen", text: "Abgeschlossen" },
  { wert: "storniert", text: "Storniert" },
];

export function ProjektFormular({
  aktion,
  kunden,
  werte = {},
  knopf,
}: {
  aktion: (vorher: Ergebnis, daten: FormData) => Promise<Ergebnis>;
  kunden: { id: string; name: string }[];
  werte?: ProjektWerte;
  knopf: string;
}) {
  const [ergebnis, absenden] = useActionState<Ergebnis, FormData>(aktion, {});
  const f = (name: string) => ergebnis.feldFehler?.[name];

  return (
    <form action={absenden} className="formular">
      {werte.id && <input type="hidden" name="id" value={werte.id} />}
      {ergebnis.fehler && <Abbruch>{ergebnis.fehler}</Abbruch>}

      <Feld
        name="bezeichnung"
        label="Bezeichnung"
        defaultValue={werte.bezeichnung ?? ""}
        fehler={f("bezeichnung")}
        placeholder="z. B. Bad Erdgeschoss, Lindenstraße 4"
        required
        autoFocus={!werte.id}
      />

      <Feld name="kunde_id" label="Kunde" fehler={f("kunde_id")}>
        <select
          id="kunde_id"
          name="kunde_id"
          className="feld"
          defaultValue={werte.kunde_id ?? ""}
          required
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

      <div className="reihe" style={{ alignItems: "flex-start" }}>
        <div style={{ flex: 1, minWidth: "12rem" }}>
          <Feld name="nummer" label="Projektnummer" defaultValue={werte.nummer ?? ""} fehler={f("nummer")} />
        </div>
        <div style={{ flex: 1, minWidth: "12rem" }}>
          <Feld name="status" label="Status" fehler={f("status")}>
            <select id="status" name="status" className="feld" defaultValue={werte.status ?? "geplant"}>
              {ZUSTAENDE.map((z) => (
                <option key={z.wert} value={z.wert}>
                  {z.text}
                </option>
              ))}
            </select>
          </Feld>
        </div>
      </div>

      <p className="gruppenlabel" style={{ marginTop: "var(--abstand-2)" }}>
        Baustelle
      </p>
      <Feld name="strasse" label="Straße" defaultValue={werte.strasse ?? ""} fehler={f("strasse")} />
      <div className="reihe" style={{ alignItems: "flex-start" }}>
        <div style={{ width: "8rem" }}>
          <Feld name="plz" label="PLZ" defaultValue={werte.plz ?? ""} fehler={f("plz")} inputMode="numeric" />
        </div>
        <div style={{ flex: 1, minWidth: "12rem" }}>
          <Feld name="ort" label="Ort" defaultValue={werte.ort ?? ""} fehler={f("ort")} />
        </div>
      </div>

      <div className="reihe" style={{ alignItems: "flex-start" }}>
        <div style={{ flex: 1, minWidth: "11rem" }}>
          <Feld name="beginn" label="Beginn" type="date" defaultValue={werte.beginn ?? ""} fehler={f("beginn")} />
        </div>
        <div style={{ flex: 1, minWidth: "11rem" }}>
          <Feld name="ende" label="Ende" type="date" defaultValue={werte.ende ?? ""} fehler={f("ende")} />
        </div>
      </div>

      <div className="reihe">
        <Absenden laeuft="Wird gespeichert …">{knopf}</Absenden>
        <Link className="taste taste-sekundaer" href={werte.id ? `/projekte/${werte.id}` : "/projekte"}>
          Abbrechen
        </Link>
      </div>
    </form>
  );
}
