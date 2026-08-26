import Link from "next/link";
import { serverKlient } from "@/lib/supabase/server";
import { Abbruch, Leer } from "@/komponenten/Zustand";
import { BELEG_ART_TEXT, BELEG_STATUS_ABZEICHEN, BELEG_STATUS_TEXT } from "@/lib/beleg";
import { alsDatum, alsEuro } from "@/lib/geld";

export default async function Belege() {
  const supabase = await serverKlient();
  const { data, error } = await supabase
    .from("beleg")
    .select("id, art, status, nummer, datum, betreff, brutto, kunde(name)")
    .order("erstellt_am", { ascending: false });

  const { count: kunden } = await supabase.from("kunde").select("*", { count: "exact", head: true });

  return (
    <>
      <div className="reihe" style={{ justifyContent: "space-between" }}>
        <div>
          <h1 className="seitentitel">Belege</h1>
          <p className="zusatz">{data ? `${data.length} Einträge` : " "}</p>
        </div>
        {(kunden ?? 0) > 0 && (
          <Link className="taste taste-primaer" href="/belege/neu">
            Angebot schreiben
          </Link>
        )}
      </div>

      {error && <Abbruch>{error.message}</Abbruch>}

      {!error && (kunden ?? 0) === 0 && (
        <Leer
          titel="Zuerst ein Kunde"
          text="Jeder Beleg gehört zu einem Kunden."
          aktion={{ pfad: "/kunden/neu", text: "Kunde anlegen" }}
        />
      )}

      {!error && (kunden ?? 0) > 0 && data && data.length === 0 && (
        <Leer
          titel="Noch keine Belege"
          text="Ein Angebot ist der Anfang jedes Auftrags."
          aktion={{ pfad: "/belege/neu", text: "Angebot schreiben" }}
        />
      )}

      {!error && data && data.length > 0 && (
        <div className="gestapelt">
          {data.map((b) => {
            const kunde = b.kunde as unknown as { name: string } | null;
            return (
              <Link key={b.id} href={`/belege/${b.id}`} className="karte listenzeile">
                <span>
                  <span className="zeilentitel">
                    {b.nummer ?? BELEG_ART_TEXT[b.art] ?? b.art}
                    {b.betreff ? ` · ${b.betreff}` : ""}
                  </span>
                  <br />
                  <span className="zusatz">
                    {[BELEG_ART_TEXT[b.art] ?? b.art, kunde?.name, alsDatum(b.datum)]
                      .filter(Boolean)
                      .join(" · ")}
                  </span>
                </span>
                <span className="reihe">
                  <span className="zahl">{alsEuro(b.brutto)}</span>
                  <span className={`abzeichen ${BELEG_STATUS_ABZEICHEN[b.status] ?? ""}`}>
                    {BELEG_STATUS_TEXT[b.status] ?? b.status}
                  </span>
                </span>
              </Link>
            );
          })}
        </div>
      )}
    </>
  );
}
