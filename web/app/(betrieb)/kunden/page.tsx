import Link from "next/link";
import { serverKlient } from "@/lib/supabase/server";
import { Abbruch, Leer } from "@/komponenten/Zustand";

export default async function Kunden({
  searchParams,
}: {
  searchParams: Promise<{ suche?: string }>;
}) {
  const { suche } = await searchParams;
  const supabase = await serverKlient();

  let abfrage = supabase
    .from("kunde")
    .select("id, nummer, name, plz, ort, reverse_charge_bau")
    .order("name");

  // Nur der Textfilter wird gesetzt — die Mandantengrenze kommt aus der Policy,
  // nicht aus dieser Abfrage.
  if (suche && suche.trim() !== "") {
    const s = suche.trim().replace(/[%,()]/g, "");
    abfrage = abfrage.or(`name.ilike.%${s}%,nummer.ilike.%${s}%,ort.ilike.%${s}%`);
  }

  const { data, error } = await abfrage;

  return (
    <>
      <div className="reihe" style={{ justifyContent: "space-between" }}>
        <div>
          <h1 className="seitentitel">Kunden</h1>
          <p className="zusatz">{data ? `${data.length} Einträge` : " "}</p>
        </div>
        <Link className="taste taste-primaer" href="/kunden/neu">
          Kunde anlegen
        </Link>
      </div>

      <form className="reihe" role="search">
        <input
          type="search"
          name="suche"
          className="feld"
          style={{ maxWidth: "24rem" }}
          placeholder="Name, Nummer oder Ort"
          defaultValue={suche ?? ""}
          aria-label="Kunden durchsuchen"
        />
        <button type="submit" className="taste taste-sekundaer">
          Suchen
        </button>
        {suche && (
          <Link className="taste taste-sekundaer" href="/kunden">
            Zurücksetzen
          </Link>
        )}
      </form>

      {error && <Abbruch>{error.message}</Abbruch>}

      {!error && data && data.length === 0 && (
        <Leer
          titel={suche ? "Nichts gefunden" : "Noch keine Kunden"}
          text={
            suche
              ? `Zu „${suche}" gibt es keinen Eintrag.`
              : "Der erste Kunde ist der Anfang jedes Angebots."
          }
          aktion={suche ? undefined : { pfad: "/kunden/neu", text: "Kunde anlegen" }}
        />
      )}

      {!error && data && data.length > 0 && (
        <div className="gestapelt">
          {data.map((k) => (
            <Link key={k.id} href={`/kunden/${k.id}`} className="karte listenzeile">
              <span>
                <span className="zeilentitel">{k.name}</span>
                <br />
                <span className="zusatz">
                  {[k.nummer, [k.plz, k.ort].filter(Boolean).join(" ")].filter(Boolean).join(" · ") ||
                    "Ohne Anschrift"}
                </span>
              </span>
              {k.reverse_charge_bau && <span className="abzeichen abzeichen-wartet">§ 13b</span>}
            </Link>
          ))}
        </div>
      )}
    </>
  );
}
