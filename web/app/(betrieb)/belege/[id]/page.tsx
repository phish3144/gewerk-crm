import Link from "next/link";
import { notFound } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { BelegBearbeiten } from "./BelegBearbeiten";
import type { Position } from "./Positionen";
import {
  BELEG_ART_TEXT,
  BELEG_STATUS_ABZEICHEN,
  BELEG_STATUS_TEXT,
  istEntwurf,
} from "@/lib/beleg";
import { alsDatum, alsEuro } from "@/lib/geld";

export default async function BelegSeite({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await serverKlient();

  const { data: beleg } = await supabase
    .from("beleg")
    .select("*, kunde(name), projekt(bezeichnung)")
    .eq("id", id)
    .maybeSingle();

  if (!beleg) notFound();

  const { data: positionen } = await supabase
    .from("beleg_position")
    .select("*")
    .eq("beleg_id", id)
    .order("position_nr");

  const kunde = beleg.kunde as unknown as { name: string } | null;
  const projekt = beleg.projekt as unknown as { bezeichnung: string } | null;
  const entwurf = istEntwurf(beleg.status);

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href="/belege">← Belege</Link>
        </p>
        <div className="reihe" style={{ justifyContent: "space-between" }}>
          <div>
            <h1 className="seitentitel">
              {beleg.nummer ?? `${BELEG_ART_TEXT[beleg.art] ?? beleg.art} (Entwurf)`}
            </h1>
            <p className="zusatz">
              {[
                BELEG_ART_TEXT[beleg.art] ?? beleg.art,
                kunde?.name,
                projekt?.bezeichnung,
                alsDatum(beleg.datum),
              ]
                .filter(Boolean)
                .join(" · ")}
            </p>
          </div>
          <span className={`abzeichen ${BELEG_STATUS_ABZEICHEN[beleg.status] ?? ""}`}>
            {BELEG_STATUS_TEXT[beleg.status] ?? beleg.status}
          </span>
        </div>
      </div>

      {beleg.art === "nachtrag" && entwurf && (
        <p className="hinweis" role="status">
          Die Positionen kommen aus den Ist-Mengen und stehen bewusst ohne Preis da. Ab 110 % der
          Sollmenge zählen nach der Rechtsprechung des BGH zu § 2 Abs. 3 Nr. 2 VOB/B die
          <strong> tatsächlich erforderlichen Kosten</strong> der Mehrmenge, nicht der
          fortgeschriebene alte Einheitspreis. Festschreiben lässt sich der Nachtrag erst, wenn
          jeder Preis gesetzt ist.
        </p>
      )}

      {beleg.art === "nachtrag" && (
        <div className="reihe">
          <Link
            className="taste taste-sekundaer"
            href={`/bedenken/neu?projekt=${beleg.projekt_id}&nachtrag=${beleg.id}`}
          >
            Bedenken anzeigen (§ 4 Abs. 3 VOB/B)
          </Link>
          {beleg.vorgaenger_id && (
            <Link className="taste taste-sekundaer" href={`/belege/${beleg.vorgaenger_id}`}>
              Zum Hauptauftrag
            </Link>
          )}
        </div>
      )}

      {!entwurf && (
        <p className="hinweis hinweis-freundlich">
          Dieser Beleg ist festgeschrieben und damit unveränderlich (GoBD). Eine Korrektur
          erfolgt über einen Storno, nicht durch Ändern.
        </p>
      )}

      <div className="karte">
        <div className="summen">
          <div className="summenzeile">
            <span className="zusatz">Netto</span>
            <span className="zahl">{alsEuro(beleg.netto)}</span>
          </div>
          <div className="summenzeile">
            <span className="zusatz">Umsatzsteuer</span>
            <span className="zahl">{alsEuro(beleg.steuer)}</span>
          </div>
          <div className="summenzeile gesamt">
            <span>Brutto</span>
            <span className="zahl">{alsEuro(beleg.brutto)}</span>
          </div>
        </div>
      </div>

      <BelegBearbeiten
        belegId={beleg.id}
        art={beleg.art}
        status={beleg.status}
        nummer={beleg.nummer}
        positionen={(positionen ?? []) as Position[]}
        gesperrt={!entwurf}
      />
    </>
  );
}
