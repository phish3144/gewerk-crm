import Link from "next/link";
import { notFound } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { alsDatum } from "@/lib/geld";
import { Bearbeiten } from "./Bearbeiten";
import { Versenden } from "./Versenden";

export default async function BedenkenSeite({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await serverKlient();

  const { data: anzeige } = await supabase
    .from("bedenkenanzeige")
    .select(
      "id, projekt_id, nachtrag_id, betreff, sachverhalt, folgen, erstellt_am, versendet_am, versendet_wie, versendet_an, projekt(nummer, bezeichnung)",
    )
    .eq("id", id)
    .maybeSingle();
  if (!anzeige) notFound();

  const { data: verweise } = await supabase
    .from("bedenken_nachweis")
    .select("dokumentation_id, dokumentation(id, art, text, r2_key, erfasst_am)")
    .eq("bedenkenanzeige_id", id);

  const projekt = anzeige.projekt as unknown as { nummer: string | null; bezeichnung: string } | null;
  const versendet = Boolean(anzeige.versendet_am);

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href={`/projekte/${anzeige.projekt_id}`}>← {projekt?.bezeichnung ?? "Baustelle"}</Link>
        </p>
        <h1 className="seitentitel">{anzeige.betreff}</h1>
        <p className="zusatz">
          Bedenkenanzeige nach § 4 Abs. 3 VOB/B · angelegt {alsDatum(anzeige.erstellt_am)}
          {versendet && (
            <>
              {" · "}
              <span className="abzeichen abzeichen-erfolg">
                versendet {alsDatum(anzeige.versendet_am)}
              </span>
            </>
          )}
        </p>
      </div>

      <div className="reihe">
        <a className="taste taste-primaer" href={`/api/bedenkenanzeige/${id}/pdf`} target="_blank" rel="noreferrer">
          PDF öffnen
        </a>
        {anzeige.nachtrag_id && (
          <Link className="taste taste-sekundaer" href={`/belege/${anzeige.nachtrag_id}`}>
            Zum Nachtrag
          </Link>
        )}
      </div>

      {versendet ? (
        <>
          <div className="karte gestapelt">
            <h2 className="kartentitel">Sachverhalt</h2>
            <p style={{ whiteSpace: "pre-wrap" }}>{anzeige.sachverhalt}</p>
            {anzeige.folgen && (
              <>
                <p className="gruppenlabel">Mögliche Folgen</p>
                <p style={{ whiteSpace: "pre-wrap" }}>{anzeige.folgen}</p>
              </>
            )}
          </div>
          <div className="karte gestapelt">
            <h2 className="kartentitel">Versand</h2>
            <p className="zusatz">
              {alsDatum(anzeige.versendet_am)} · {anzeige.versendet_wie} · an{" "}
              {anzeige.versendet_an}
            </p>
            <p className="zusatz">
              Ab hier unveränderlich. Eine Korrektur läuft über eine neue Anzeige, nicht über eine
              Änderung dieser — sonst wäre der belegbare Zeitpunkt nichts mehr wert.
            </p>
          </div>
        </>
      ) : (
        <>
          <Bearbeiten
            id={anzeige.id}
            betreff={anzeige.betreff}
            sachverhalt={anzeige.sachverhalt}
            folgen={anzeige.folgen}
          />
          <Versenden id={anzeige.id} />
        </>
      )}

      {(verweise ?? []).length > 0 && (
        <div className="karte gestapelt">
          <h2 className="kartentitel">Nachweise</h2>
          {(verweise ?? []).map((v) => {
            const d = v.dokumentation as unknown as {
              id: string;
              art: string;
              text: string | null;
              r2_key: string | null;
              erfasst_am: string;
            } | null;
            if (!d) return null;
            return (
              <div key={d.id} className="gestapelt">
                <p className="zusatz">
                  {alsDatum(d.erfasst_am)} · {d.art}
                </p>
                {d.text && <p>{d.text}</p>}
                {d.r2_key && (
                  <img
                    src={`/api/dokument?k=${encodeURIComponent(d.r2_key)}`}
                    alt={d.text ?? "Baustellenfoto"}
                    style={{ maxWidth: "24rem", borderRadius: "var(--radius)" }}
                  />
                )}
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
