import Link from "next/link";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { serverKlient } from "@/lib/supabase/server";
import { alsDatum, alsEuro, alsMenge } from "@/lib/geld";
import { Kennzahl } from "./Kennzahl";

const FRIST_TEXT: Record<string, string> = {
  gewaehrleistung: "Gewährleistung",
  freistellungsbescheinigung: "Freistellungsbescheinigung (§ 48b EStG)",
  sicherheitseinbehalt: "Sicherheitseinbehalt (§ 17 VOB/B)",
  skontofrist: "Skontofrist",
  zahlungsziel: "Zahlungsziel",
};

function tageText(tage: number): string {
  if (tage < 0) return `seit ${Math.abs(tage)} Tagen überfällig`;
  if (tage === 0) return "heute";
  if (tage === 1) return "morgen";
  return `in ${tage} Tagen`;
}

// Die Startseite. Sie zeigt, was Geld kostet - und zwar so, dass jede Zahl
// sich bis auf die einzelne Zeile aufklappen laesst.
export default async function Uebersicht() {
  const aktiv = await aktiveZugehoerigkeit();
  const supabase = await serverKlient();

  const [ungeklaert, posten, fristenRoh, kalk] = await Promise.all([
    supabase
      .from("ungeklaerte_leistung")
      .select("projekt_id, gegenstand, gegenstand_id, regel, bezeichnung, menge, einheit, betrag")
      .order("betrag", { ascending: false }),
    supabase
      .from("offene_posten")
      .select("beleg_id, nummer, kunde, brutto, offen, faelligkeit_am, tage_bis_faellig")
      .order("tage_bis_faellig"),
    // Das Zahlungsziel steht schon in den offenen Posten - dieselbe Rechnung
    // zweimal auf derselben Seite verwaessert beide Zahlen. Auf der Uebersicht
    // zeigt die Fristenkarte deshalb genau das, was sonst nirgends steht:
    // Gewaehrleistung, Freistellungsbescheinigung, Sicherheitseinbehalt und
    // die Skontofrist. In der Sicht selbst bleibt das Zahlungsziel enthalten,
    // denn eine Frist ist es.
    supabase
      .from("fristen")
      .select("art, projekt_id, gegenstand_id, bezeichnung, faellig_am, tage, betrag, herkunft")
      .neq("art", "zahlungsziel")
      .lte("tage", 90)
      .order("tage"),
    supabase
      .from("nachkalkulation")
      .select("projekt_id, bezeichnung, auftragssumme, lohn_geplant, material_geplant, lohn_ist, material_ist, stunden_ist")
      .order("auftragssumme", { ascending: false })
      .limit(20),
  ]);

  const meldungen = ungeklaert.data ?? [];
  const offene = posten.data ?? [];
  const fristen = fristenRoh.data ?? [];
  const projekte = (kalk.data ?? []).filter(
    (p) => Number(p.auftragssumme) > 0 || Number(p.lohn_ist) > 0 || Number(p.material_ist) > 0,
  );

  const summeUngeklaert = meldungen.reduce((s, m) => s + Number(m.betrag ?? 0), 0);
  const summeOffen = offene.reduce((s, o) => s + Number(o.offen ?? 0), 0);
  const ueberfaellig = offene.filter((o) => Number(o.tage_bis_faellig) < 0);
  const summeUeberfaellig = ueberfaellig.reduce((s, o) => s + Number(o.offen ?? 0), 0);
  const dringend = fristen.filter((f) => Number(f.tage) <= 14);

  const fehler = [ungeklaert.error, posten.error, fristenRoh.error, kalk.error].filter(Boolean);

  return (
    <>
      <div>
        <h1 className="seitentitel">{aktiv?.name}</h1>
        <p className="zusatz">Was heute Geld kostet</p>
      </div>

      {fehler.map((f, i) => (
        <p key={i} className="hinweis" role="alert">
          Eine Kennzahl konnte nicht geladen werden: {f!.message}
        </p>
      ))}

      <div className="kennzahlreihe">
        <Kennzahl
          titel="Nicht beauftragt"
          wert={alsEuro(summeUngeklaert)}
          zusatz={`${meldungen.length} ${meldungen.length === 1 ? "Meldung" : "Meldungen"}`}
          ton={summeUngeklaert > 0 ? "warnung" : "neutral"}
          leer="Jede Stunde und jede Entnahme hängt an einer beauftragten Position."
          zeilen={meldungen.slice(0, 12).map((m) => (
            <div key={`${m.gegenstand}-${m.gegenstand_id}`} className="herkunftzeile">
              <span>
                {m.bezeichnung}
                <br />
                <span className="zusatz">
                  {m.regel === "mehrmenge" ? "Mehrmenge über 110 %" : "ohne Position"} ·{" "}
                  {alsMenge(m.menge)} {m.einheit}
                </span>
              </span>
              <span className="zahl">{alsEuro(m.betrag)}</span>
            </div>
          ))}
        />

        <Kennzahl
          titel="Offene Posten"
          wert={alsEuro(summeOffen)}
          zusatz={
            ueberfaellig.length > 0
              ? `davon ${alsEuro(summeUeberfaellig)} überfällig`
              : `${offene.length} ${offene.length === 1 ? "Rechnung" : "Rechnungen"}`
          }
          ton={summeUeberfaellig > 0 ? "gefahr" : "neutral"}
          leer="Alles bezahlt."
          zeilen={offene.slice(0, 12).map((o) => (
            <Link key={o.beleg_id} href={`/belege/${o.beleg_id}`} className="herkunftzeile">
              <span>
                {o.nummer} · {o.kunde}
                <br />
                <span className="zusatz">
                  {o.faelligkeit_am
                    ? `fällig ${alsDatum(o.faelligkeit_am)} — ${tageText(Number(o.tage_bis_faellig))}`
                    : "ohne Zahlungsziel"}
                </span>
              </span>
              <span className="zahl">{alsEuro(o.offen)}</span>
            </Link>
          ))}
        />

        <Kennzahl
          titel="Fristen"
          wert={String(dringend.length)}
          zusatz={
            dringend.length > 0
              ? "in den nächsten 14 Tagen"
              : `${fristen.length} in den nächsten 90 Tagen`
          }
          ton={dringend.length > 0 ? "warnung" : "neutral"}
          leer="Nichts läuft in den nächsten 90 Tagen ab."
          zeilen={fristen.slice(0, 12).map((f) => (
            <div key={`${f.art}-${f.gegenstand_id}`} className="herkunftzeile">
              <span>
                {FRIST_TEXT[f.art] ?? f.art}: {f.bezeichnung}
                <br />
                <span className="zusatz">
                  {alsDatum(f.faellig_am)} — {tageText(Number(f.tage))} · {f.herkunft}
                </span>
              </span>
              {f.betrag != null && <span className="zahl">{alsEuro(f.betrag)}</span>}
            </div>
          ))}
        />
      </div>

      <div className="karte gestapelt">
        <h2 className="kartentitel">Nachkalkulation</h2>
        <p className="zusatz">
          Geplant gegen tatsächlich. Die geplante Seite kommt aus den Kalkulationsanteilen der
          Auftrags- und Nachtragspositionen, die tatsächliche aus erfassten Stunden und
          Materialentnahmen. Gemeinkosten stehen bewusst nicht drin — welcher Zuschlag richtig
          ist, entscheidet der Betrieb, nicht die Anwendung.
        </p>

        {projekte.length === 0 ? (
          <p className="zusatz">Noch keine Baustelle mit Auftrag oder erfassten Kosten.</p>
        ) : (
          projekte.map((p) => {
            const geplant = Number(p.lohn_geplant) + Number(p.material_geplant);
            const ist = Number(p.lohn_ist) + Number(p.material_ist);
            const ueber = ist > geplant && geplant > 0;
            return (
              <Link key={p.projekt_id} href={`/projekte/${p.projekt_id}`} className="herkunftzeile">
                <span>
                  {p.bezeichnung}
                  <br />
                  <span className="zusatz">
                    Auftrag {alsEuro(p.auftragssumme)} · geplante Kosten {alsEuro(geplant)} ·{" "}
                    {alsMenge(p.stunden_ist)} Std erfasst
                  </span>
                </span>
                <span className={`zahl ${ueber ? "ueberzogen" : ""}`}>
                  {alsEuro(ist)}
                  <br />
                  <span className="zusatz">
                    {geplant > 0
                      ? `${Math.round((ist / geplant) * 100)} % der Planung`
                      : "keine Planung hinterlegt"}
                  </span>
                </span>
              </Link>
            );
          })
        )}
      </div>
    </>
  );
}
