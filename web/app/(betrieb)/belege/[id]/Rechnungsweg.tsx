"use client";

import { useActionState } from "react";
import { abschlaegeAnrechnen, rechnungAusAuftrag, zahlungErfassen } from "../aktionen";
import { Absenden } from "@/komponenten/Absenden";
import { alsEuro, alsDatum } from "@/lib/geld";

// Aus dem Auftrag entsteht die Rechnung. Drei Arten, weil § 632a BGB und
// § 16 VOB/B drei verschiedene Vorgaenge kennen - und weil eine
// Abschlagsrechnung umsatzsteuerlich etwas anderes ist als eine Teilrechnung.
export function RechnungAusAuftrag({ auftragId }: { auftragId: string }) {
  const [stand, absenden] = useActionState(rechnungAusAuftrag, {});
  return (
    <form action={absenden} className="karte gestapelt">
      <h2 className="kartentitel">Rechnung schreiben</h2>
      <input type="hidden" name="id" value={auftragId} />
      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}
      <label className="eingabe">
        <span>Art</span>
        <select className="feld" name="art" defaultValue="schlussrechnung">
          <option value="abschlagsrechnung">Abschlagsrechnung (§ 632a BGB)</option>
          <option value="teilrechnung">Teilrechnung</option>
          <option value="schlussrechnung">Schlussrechnung — mit allen Nachträgen</option>
        </select>
      </label>
      <p className="zusatz">
        Bei der Schlussrechnung kommen die festgeschriebenen Nachträge dieser Baustelle mit. Ohne
        sie wäre der Nachtrag zwar erfasst, aber nie berechnet.
      </p>
      <div>
        <Absenden>Rechnung anlegen</Absenden>
      </div>
    </form>
  );
}

export function Zahlungen({
  belegId,
  zahlungen,
  offen,
}: {
  belegId: string;
  zahlungen: Array<{
    id: string;
    vereinnahmt_am: string;
    betrag_brutto: number | string;
    art: string;
    status_rc: string;
  }>;
  offen: number;
}) {
  const [stand, absenden] = useActionState(zahlungErfassen, {});
  const heute = new Date().toISOString().slice(0, 10);

  return (
    <div className="karte gestapelt">
      <h2 className="kartentitel">Zahlungen</h2>

      {zahlungen.length === 0 ? (
        <p className="zusatz">Noch nichts eingegangen.</p>
      ) : (
        zahlungen.map((z) => (
          <div key={z.id} className="reihe" style={{ justifyContent: "space-between" }}>
            <span className="zusatz">
              {alsDatum(z.vereinnahmt_am)} · {z.art}
              {z.status_rc === "rc_13b_nr4" && " · § 13b"}
            </span>
            <span className="zahl">{alsEuro(z.betrag_brutto)}</span>
          </div>
        ))
      )}

      <div className="reihe" style={{ justifyContent: "space-between" }}>
        <span className="zusatz">Noch offen</span>
        <span className="zahl">{alsEuro(offen)}</span>
      </div>

      <form action={absenden} className="gestapelt">
        <input type="hidden" name="beleg_id" value={belegId} />
        {stand.fehler && (
          <p className="hinweis" role="alert">
            {stand.fehler}
          </p>
        )}
        {stand.hinweis && (
          <p className="hinweis hinweis-freundlich" role="status">
            {stand.hinweis}
          </p>
        )}

        <div className="reihe" style={{ alignItems: "flex-end" }}>
          <label className="eingabe" style={{ width: "11rem" }}>
            <span>Gutschrift auf dem Konto</span>
            <input type="date" className="feld" name="vereinnahmt_am" defaultValue={heute} max={heute} />
          </label>
          <label className="eingabe" style={{ width: "9rem" }}>
            <span>Betrag brutto</span>
            <input className="feld zahl" name="betrag_brutto" inputMode="decimal" defaultValue="" />
          </label>
          <label className="eingabe" style={{ width: "7rem" }}>
            <span>USt-Satz</span>
            <input className="feld zahl" name="steuersatz" inputMode="decimal" defaultValue="19" />
          </label>
          <label className="eingabe" style={{ width: "11rem" }}>
            <span>Art</span>
            <select className="feld" name="art" defaultValue="abschlag">
              <option value="abschlag">Abschlagszahlung</option>
              <option value="teilzahlung">Teilzahlung</option>
              <option value="schlusszahlung">Schlusszahlung</option>
              <option value="vorauszahlung">Vorauszahlung</option>
            </select>
          </label>
        </div>
        {stand.feldFehler?.["vereinnahmt_am"] && (
          <p className="feldfehler">{stand.feldFehler["vereinnahmt_am"]}</p>
        )}
        {stand.feldFehler?.["betrag_brutto"] && (
          <p className="feldfehler">{stand.feldFehler["betrag_brutto"]}</p>
        )}
        <label className="reihe" style={{ gap: "var(--abstand-2)" }}>
          <input type="checkbox" name="reverse_charge" value="ja" />
          <span className="zusatz">
            Steuerschuldnerschaft des Leistungsempfängers (§ 13b UStG) — dann wird keine Steuer
            ausgewiesen
          </span>
        </label>
        <p className="zusatz">
          Maßgeblich ist das <strong>Gutschriftsdatum des Bankkontos</strong> — nicht die
          Wertstellung, nicht der Überweisungsauftrag (UStAE 13.6 Abs. 1 Satz 3). Davon hängt ab,
          wann die Umsatzsteuer entsteht.
        </p>
        <div>
          <Absenden art="taste-sekundaer">Zahlung erfassen</Absenden>
        </div>
      </form>
    </div>
  );
}

export function Absetzung({ belegId, anzahl }: { belegId: string; anzahl: number }) {
  const [stand, absenden] = useActionState(abschlaegeAnrechnen, {});
  return (
    <form action={absenden} className="karte gestapelt">
      <h2 className="kartentitel">Abschläge absetzen</h2>
      <input type="hidden" name="id" value={belegId} />
      {stand.fehler && (
        <p className="hinweis" role="alert">
          {stand.fehler}
        </p>
      )}
      {stand.hinweis && (
        <p className="hinweis hinweis-freundlich" role="status">
          {stand.hinweis}
        </p>
      )}
      <p className="zusatz">
        {anzahl > 0
          ? `${anzahl} Abschlagszahlung(en) sind abgesetzt.`
          : "Noch nichts abgesetzt."}{" "}
        Die vereinnahmten Teilentgelte <strong>und</strong> die darauf entfallende Umsatzsteuer
        gehören in die Schlussrechnung (§ 14 Abs. 5 Satz 2 UStG). Wer das unterlässt, schuldet die
        Steuer auf die Anzahlungen ein zweites Mal — die Datenbank lässt das Festschreiben deshalb
        gar nicht erst zu.
      </p>
      <div>
        <Absenden art="taste-sekundaer">Abschläge jetzt absetzen</Absenden>
      </div>
    </form>
  );
}
