import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { serverKlient } from "@/lib/supabase/server";

// Erste echte Abfrage gegen die Datenbank. Sie zaehlt nur — aber sie zaehlt
// durch RLS, und genau das ist an dieser Stelle der Beweis: was hier steht,
// gehoert zum aktiven Betrieb und zu keinem anderen.
async function bestand() {
  const supabase = await serverKlient();
  const [kunden, projekte, belege] = await Promise.all([
    supabase.from("kunde").select("*", { count: "exact", head: true }),
    supabase.from("projekt").select("*", { count: "exact", head: true }),
    supabase.from("beleg").select("*", { count: "exact", head: true }),
  ]);
  return {
    kunden: kunden.count ?? 0,
    projekte: projekte.count ?? 0,
    belege: belege.count ?? 0,
  };
}

export default async function Uebersicht() {
  const aktiv = await aktiveZugehoerigkeit();
  const zahlen = await bestand();
  const leer = zahlen.kunden === 0 && zahlen.projekte === 0 && zahlen.belege === 0;

  return (
    <>
      <div>
        <h1 className="seitentitel">{aktiv?.name}</h1>
        <p className="zusatz">Übersicht</p>
      </div>

      {leer && (
        <p className="hinweis hinweis-freundlich">
          Noch nichts erfasst. Kunden, Projekte und Angebote kommen in den nächsten Schritten
          dazu.
        </p>
      )}

      <div className="reihe" style={{ alignItems: "stretch" }}>
        {[
          { titel: "Kunden", wert: zahlen.kunden },
          { titel: "Projekte", wert: zahlen.projekte },
          { titel: "Belege", wert: zahlen.belege },
        ].map((k) => (
          <div key={k.titel} className="karte" style={{ minWidth: "12rem", flex: "1 1 12rem" }}>
            <p className="gruppenlabel">{k.titel}</p>
            <p className="kennzahl">{k.wert}</p>
          </div>
        ))}
      </div>
    </>
  );
}
