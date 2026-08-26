"use client";

import Link from "next/link";
import { useActionState } from "react";
import { Absenden } from "@/komponenten/Absenden";
import { Feld } from "@/komponenten/Feld";
import { Abbruch } from "@/komponenten/Zustand";
import type { Ergebnis } from "@/lib/formular";

export type KundeWerte = {
  id?: string;
  name?: string | null;
  nummer?: string | null;
  strasse?: string | null;
  plz?: string | null;
  ort?: string | null;
  ust_id?: string | null;
  reverse_charge_bau?: boolean | null;
  zahlungsziel_tage?: number | null;
  skonto_prozent?: number | null;
  skonto_tage?: number | null;
};

export function KundeFormular({
  aktion,
  werte = {},
  knopf,
}: {
  aktion: (vorher: Ergebnis, daten: FormData) => Promise<Ergebnis>;
  werte?: KundeWerte;
  knopf: string;
}) {
  const [ergebnis, absenden] = useActionState<Ergebnis, FormData>(aktion, {});
  const f = (name: string) => ergebnis.feldFehler?.[name];

  return (
    <form action={absenden} className="formular">
      {werte.id && <input type="hidden" name="id" value={werte.id} />}
      {ergebnis.fehler && <Abbruch>{ergebnis.fehler}</Abbruch>}

      <Feld
        name="name"
        label="Name"
        defaultValue={werte.name ?? ""}
        fehler={f("name")}
        required
        autoFocus={!werte.id}
      />
      <Feld
        name="nummer"
        label="Kundennummer"
        defaultValue={werte.nummer ?? ""}
        fehler={f("nummer")}
        hinweis="Frei wählbar. Leer lassen, wenn Sie keine führen."
      />

      <p className="gruppenlabel" style={{ marginTop: "var(--abstand-2)" }}>
        Anschrift
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

      <p className="gruppenlabel" style={{ marginTop: "var(--abstand-2)" }}>
        Zahlung
      </p>
      <Feld
        name="ust_id"
        label="USt-IdNr."
        defaultValue={werte.ust_id ?? ""}
        fehler={f("ust_id")}
        hinweis="Nötig, wenn ohne Umsatzsteuer abgerechnet wird."
      />
      <div className="reihe" style={{ alignItems: "flex-start" }}>
        <div style={{ width: "10rem" }}>
          <Feld
            name="zahlungsziel_tage"
            label="Zahlungsziel"
            type="number"
            min={0}
            defaultValue={werte.zahlungsziel_tage ?? 14}
            fehler={f("zahlungsziel_tage")}
            hinweis="Tage"
          />
        </div>
        <div style={{ width: "10rem" }}>
          <Feld
            name="skonto_prozent"
            label="Skonto"
            type="number"
            step="0.01"
            min={0}
            max={99.99}
            defaultValue={werte.skonto_prozent ?? 0}
            fehler={f("skonto_prozent")}
            hinweis="Prozent"
          />
        </div>
        <div style={{ width: "10rem" }}>
          <Feld
            name="skonto_tage"
            label="Skontofrist"
            type="number"
            min={0}
            defaultValue={werte.skonto_tage ?? 0}
            fehler={f("skonto_tage")}
            hinweis="Tage"
          />
        </div>
      </div>

      <label className="reihe" style={{ gap: "var(--abstand-3)", cursor: "pointer" }}>
        <input
          type="checkbox"
          name="reverse_charge_bau"
          defaultChecked={werte.reverse_charge_bau ?? false}
          style={{ width: 22, height: 22 }}
        />
        <span>
          <span className="zeilentitel">Bauleistungen ohne Umsatzsteuer (§ 13b UStG)</span>
          <br />
          <span className="zusatz">
            Nur ankreuzen, wenn dieser Kunde selbst Bauleistungen erbringt.
          </span>
        </span>
      </label>

      <div className="reihe">
        <Absenden laeuft="Wird gespeichert …">{knopf}</Absenden>
        <Link className="taste taste-sekundaer" href={werte.id ? `/kunden/${werte.id}` : "/kunden"}>
          Abbrechen
        </Link>
      </div>
    </form>
  );
}
