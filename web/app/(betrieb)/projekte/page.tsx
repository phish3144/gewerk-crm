import Link from "next/link";
import { serverKlient } from "@/lib/supabase/server";
import { Abbruch, Leer } from "@/komponenten/Zustand";

const ABZEICHEN: Record<string, string> = {
  geplant: "abzeichen-wartet",
  laufend: "abzeichen-erfolg",
  abgeschlossen: "abzeichen",
  storniert: "abzeichen-kritisch",
};
const TEXT: Record<string, string> = {
  geplant: "Geplant",
  laufend: "Laufend",
  abgeschlossen: "Abgeschlossen",
  storniert: "Storniert",
};

export default async function Projekte({
  searchParams,
}: {
  searchParams: Promise<{ suche?: string }>;
}) {
  const { suche } = await searchParams;
  const supabase = await serverKlient();

  let abfrage = supabase
    .from("projekt")
    .select("id, nummer, bezeichnung, plz, ort, status, kunde(name)")
    .order("angelegt_am", { ascending: false });

  if (suche && suche.trim() !== "") {
    const s = suche.trim().replace(/[%,()]/g, "");
    abfrage = abfrage.or(`bezeichnung.ilike.%${s}%,nummer.ilike.%${s}%,ort.ilike.%${s}%`);
  }

  const { data, error } = await abfrage;
  const { count: kunden } = await supabase
    .from("kunde")
    .select("*", { count: "exact", head: true });

  return (
    <>
      <div className="reihe" style={{ justifyContent: "space-between" }}>
        <div>
          <h1 className="seitentitel">Projekte</h1>
          <p className="zusatz">{data ? `${data.length} Einträge` : " "}</p>
        </div>
        {(kunden ?? 0) > 0 && (
          <Link className="taste taste-primaer" href="/projekte/neu">
            Projekt anlegen
          </Link>
        )}
      </div>

      <form className="reihe" role="search">
        <input
          type="search"
          name="suche"
          className="feld"
          style={{ maxWidth: "24rem" }}
          placeholder="Bezeichnung, Nummer oder Ort"
          defaultValue={suche ?? ""}
          aria-label="Projekte durchsuchen"
        />
        <button type="submit" className="taste taste-sekundaer">
          Suchen
        </button>
        {suche && (
          <Link className="taste taste-sekundaer" href="/projekte">
            Zurücksetzen
          </Link>
        )}
      </form>

      {error && <Abbruch>{error.message}</Abbruch>}

      {/* Ein Projekt haengt an einem Kunden. Ohne Kunden fuehrt der Weg dorthin,
          statt in ein Formular mit leerer Auswahlliste. */}
      {!error && (kunden ?? 0) === 0 && (
        <Leer
          titel="Zuerst ein Kunde"
          text="Jedes Projekt gehört zu einem Kunden. Legen Sie zuerst einen an."
          aktion={{ pfad: "/kunden/neu", text: "Kunde anlegen" }}
        />
      )}

      {!error && (kunden ?? 0) > 0 && data && data.length === 0 && (
        <Leer
          titel={suche ? "Nichts gefunden" : "Noch keine Projekte"}
          text={suche ? `Zu „${suche}" gibt es keinen Eintrag.` : "Hier entstehen Ihre Baustellen."}
          aktion={suche ? undefined : { pfad: "/projekte/neu", text: "Projekt anlegen" }}
        />
      )}

      {!error && data && data.length > 0 && (
        <div className="gestapelt">
          {data.map((p) => {
            const kunde = p.kunde as unknown as { name: string } | null;
            return (
              <Link key={p.id} href={`/projekte/${p.id}`} className="karte listenzeile">
                <span>
                  <span className="zeilentitel">{p.bezeichnung}</span>
                  <br />
                  <span className="zusatz">
                    {[kunde?.name, p.nummer, [p.plz, p.ort].filter(Boolean).join(" ")]
                      .filter(Boolean)
                      .join(" · ")}
                  </span>
                </span>
                <span className={`abzeichen ${ABZEICHEN[p.status ?? ""] ?? ""}`}>
                  {TEXT[p.status ?? ""] ?? p.status}
                </span>
              </Link>
            );
          })}
        </div>
      )}
    </>
  );
}
