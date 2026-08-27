import Link from "next/link";
import { serverKlient } from "@/lib/supabase/server";
import { alsEuro, alsMenge, alsDatum } from "@/lib/geld";
import { Leer, Abbruch } from "@/komponenten/Zustand";
import { Klaeren } from "./Klaeren";
import { Meldungsgruppe, MeldungsHaken } from "./Meldungsgruppe";

type Meldung = {
  projekt_id: string | null;
  gegenstand: string;
  gegenstand_id: string;
  regel: string;
  bezeichnung: string;
  menge: number | string;
  einheit: string;
  betrag: number | string;
  erfasst_am: string | null;
  nachweis_id: string | null;
  betrag_vorlaeufig: boolean;
};

// Die Buerooansicht des Nachtragswaechters.
//
// Nicht "7 Meldungen", sondern "1.240 € nicht beauftragt". Die Zahl ist die
// Botschaft — eine Zaehlung sagt einem Betrieb nichts darueber, ob sich das
// Hinsehen lohnt. Gruppiert nach Baustelle, weil dort der Nachtrag entsteht.
export default async function UngeklaertSeite() {
  const supabase = await serverKlient();

  const { data: meldungen, error } = await supabase
    .from("ungeklaerte_leistung")
    .select("*")
    .order("betrag", { ascending: false });

  if (error) {
    return (
      <>
        <h1 className="seitentitel">Ungeklärt</h1>
        <Abbruch>Die Meldungen konnten nicht geladen werden: {error.message}</Abbruch>
      </>
    );
  }

  const liste = (meldungen ?? []) as Meldung[];

  const projektIds = [...new Set(liste.map((m) => m.projekt_id).filter(Boolean))] as string[];
  const { data: projekte } = projektIds.length
    ? await supabase.from("projekt").select("id, nummer, bezeichnung").in("id", projektIds)
    : { data: [] };
  const nameVon = new Map(
    (projekte ?? []).map((p) => [p.id, [p.nummer, p.bezeichnung].filter(Boolean).join(" · ")]),
  );

  // Nachweise nachladen: der Beleg dafuer, dass da wirklich etwas war.
  const nachweisIds = [...new Set(liste.map((m) => m.nachweis_id).filter(Boolean))] as string[];
  const { data: nachweise } = nachweisIds.length
    ? await supabase.from("dokumentation").select("id, art, text, r2_key").in("id", nachweisIds)
    : { data: [] };
  const nachweisVon = new Map((nachweise ?? []).map((d) => [d.id, d]));

  const gesamt = liste.reduce((s, m) => s + Number(m.betrag ?? 0), 0);

  const proProjekt = new Map<string, Meldung[]>();
  for (const m of liste) {
    const schluessel = m.projekt_id ?? "ohne";
    proProjekt.set(schluessel, [...(proProjekt.get(schluessel) ?? []), m]);
  }
  const gruppen = [...proProjekt.entries()].sort(
    (a, b) =>
      b[1].reduce((s, m) => s + Number(m.betrag ?? 0), 0) -
      a[1].reduce((s, m) => s + Number(m.betrag ?? 0), 0),
  );

  return (
    <>
      <div>
        <h1 className="seitentitel">Ungeklärt</h1>
        <p className="zusatz">Gearbeitet, aber nicht beauftragt</p>
      </div>

      {liste.length === 0 ? (
        <Leer
          titel="Nichts offen"
          text="Jede erfasste Stunde und jede Entnahme hängt an einer beauftragten Position. So soll es sein."
          aktion={{ pfad: "/projekte", text: "Zu den Baustellen" }}
        />
      ) : (
        <>
          <div className="karte gestapelt">
            <p className="gruppenlabel">Nicht beauftragt</p>
            <p className="zahl kennzahl">{alsEuro(gesamt)}</p>
            <p className="zusatz">
              {liste.length} {liste.length === 1 ? "Meldung" : "Meldungen"} auf {gruppen.length}{" "}
              {gruppen.length === 1 ? "Baustelle" : "Baustellen"}
            </p>
          </div>

          {gruppen.map(([projektId, posten]) => (
            <div key={projektId} className="karte gestapelt">
              <div className="reihe" style={{ justifyContent: "space-between" }}>
                <h2 className="kartentitel">
                  {projektId === "ohne" ? (
                    "Ohne Baustelle"
                  ) : (
                    <Link href={`/projekte/${projektId}`}>
                      {nameVon.get(projektId) ?? "Baustelle"}
                    </Link>
                  )}
                </h2>
                <span className="zahl">
                  {alsEuro(posten.reduce((s, m) => s + Number(m.betrag ?? 0), 0))}
                </span>
              </div>

              <Meldungsgruppe
                projektId={projektId}
                betraege={Object.fromEntries(
                  posten.map((m) => [`${m.gegenstand}:${m.gegenstand_id}`, Number(m.betrag ?? 0)]),
                )}
              >
              {posten.map((m) => {
                const nachweis = m.nachweis_id ? nachweisVon.get(m.nachweis_id) : null;
                return (
                  <div
                    key={`${m.gegenstand}-${m.gegenstand_id}`}
                    className="karte gestapelt"
                    data-meldung={`${m.gegenstand}:${m.gegenstand_id}`}
                  >
                    <div className="reihe" style={{ justifyContent: "space-between" }}>
                      <span>
                        <strong>{m.bezeichnung}</strong>
                        <br />
                        <span className="zusatz">
                          {m.regel === "mehrmenge"
                            ? "Mehrmenge über 110 % — § 2 Abs. 3 Nr. 2 VOB/B"
                            : m.gegenstand === "zeiteintrag"
                              ? "Zeit ohne Position"
                              : "Material ohne Position"}
                          {m.erfasst_am && ` · ${alsDatum(m.erfasst_am)}`}
                        </span>
                      </span>
                      <span className="zahl" style={{ textAlign: "right" }}>
                        {alsEuro(m.betrag)}
                        <br />
                        <span className="zusatz">
                          {alsMenge(m.menge)} {m.einheit}
                        </span>
                      </span>
                    </div>

                    {m.betrag_vorlaeufig && (
                      <p className="hinweis">
                        Betrag vorläufig. Ab 110 % ist laut BGH nicht mehr der ursprüngliche
                        Einheitspreis maßgeblich, sondern die tatsächlich erforderlichen Kosten der
                        Mehrmenge. Die Zahl hier ist eine Größenordnung, kein Anspruch.
                      </p>
                    )}

                    {nachweis && (
                      <div className="gestapelt">
                        <p className="gruppenlabel">Nachweis von der Baustelle</p>
                        {nachweis.text && <p>{nachweis.text}</p>}
                        {nachweis.r2_key && (
                          <img
                            src={`/api/dokument?k=${encodeURIComponent(nachweis.r2_key)}`}
                            alt={nachweis.text ?? "Baustellenfoto"}
                            style={{ maxWidth: "24rem", borderRadius: "var(--radius)" }}
                          />
                        )}
                      </div>
                    )}

                    <div className="reihe" style={{ justifyContent: "space-between" }}>
                      <MeldungsHaken
                        schluessel={`${m.gegenstand}:${m.gegenstand_id}`}
                        titel={m.bezeichnung}
                      />
                      <Klaeren gegenstand={m.gegenstand} gegenstandId={m.gegenstand_id} />
                    </div>
                  </div>
                );
              })}
              </Meldungsgruppe>
            </div>
          ))}
        </>
      )}
    </>
  );
}
