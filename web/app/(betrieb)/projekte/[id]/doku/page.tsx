import Link from "next/link";
import { notFound } from "next/navigation";
import { serverKlient, angemeldeteBenutzerin } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { Baustellendoku } from "./Baustellendoku";
import { alsDatum } from "@/lib/geld";

export default async function DokuSeite({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await serverKlient();

  const { data: projekt } = await supabase
    .from("projekt")
    .select("id, bezeichnung, nummer")
    .eq("id", id)
    .maybeSingle();
  if (!projekt) notFound();

  const person = await angemeldeteBenutzerin();
  const aktiv = await aktiveZugehoerigkeit();
  const { data: mitarbeiter } = await supabase
    .from("mitarbeiter")
    .select("id")
    .eq("benutzer_id", person?.id ?? "")
    .eq("betrieb_id", aktiv?.betrieb_id ?? "")
    .maybeSingle();

  const { data: eintraege, error: dokuFehler } = await supabase
    .from("dokumentation")
    .select(
      "id, art, r2_key, text, aufmass, erfasst_am, hochgeladen_am, erfasst_von:mitarbeiter(name)",
    )
    .eq("projekt_id", id)
    .order("erfasst_am", { ascending: false });

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href={`/projekte/${id}`}>← {projekt.bezeichnung}</Link>
        </p>
        <h1 className="seitentitel">Baustellendoku</h1>
        <p className="zusatz">{(eintraege ?? []).length} Einträge</p>
      </div>

      {mitarbeiter ? (
        <Baustellendoku projektId={id} mitarbeiterId={mitarbeiter.id} />
      ) : (
        <p className="hinweis">
          Für dieses Konto gibt es hier keinen Mitarbeiterdatensatz. Ohne ihn lässt sich nichts
          erfassen.
        </p>
      )}

      {dokuFehler && (
        <p className="hinweis" role="alert">
          Die Doku konnte nicht geladen werden: {dokuFehler.message}
        </p>
      )}

      <div className="gestapelt">
        {(eintraege ?? []).map((e) => {
          const wer = e.erfasst_von as unknown as { name: string } | null;
          // Zwei Zeitpunkte, und sie duerfen auseinanderliegen: erfasst wurde
          // auf der Baustelle, uebertragen erst im Funkloch danach. Wenn beide
          // auf denselben Tag fallen, ist der Zusatz nur Laerm.
          const nachgereicht =
            e.hochgeladen_am && alsDatum(e.hochgeladen_am) !== alsDatum(e.erfasst_am)
              ? alsDatum(e.hochgeladen_am)
              : null;
          return (
            <div key={e.id} className="karte gestapelt">
              <div className="reihe" style={{ justifyContent: "space-between" }}>
                <span className="gruppenlabel">{e.art}</span>
                <span className="zusatz">
                  {alsDatum(e.erfasst_am)} · {wer?.name ?? "unbekannt"}
                  {nachgereicht && ` · übertragen ${nachgereicht}`}
                </span>
              </div>
              {e.r2_key && (
                // Ueber den Worker, nicht direkt aus dem Bucket: der ist nicht
                // oeffentlich.
                <img
                  src={`/api/dokument?k=${encodeURIComponent(e.r2_key)}`}
                  alt={e.text ?? "Baustellenfoto"}
                  style={{ maxWidth: "100%", borderRadius: "var(--radius)" }}
                />
              )}
              {e.text && <p>{e.text}</p>}
              {e.aufmass != null && (
                <pre className="zahl" style={{ whiteSpace: "pre-wrap", margin: 0 }}>
                  {JSON.stringify(e.aufmass, null, 2)}
                </pre>
              )}
            </div>
          );
        })}
        {!dokuFehler && (eintraege ?? []).length === 0 && (
          <p className="zusatz">Noch nichts dokumentiert.</p>
        )}
      </div>
    </>
  );
}
