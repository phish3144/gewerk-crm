import Link from "next/link";
import { notFound } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { BedenkenFormular } from "../BedenkenFormular";

export default async function NeueBedenkenSeite({
  searchParams,
}: {
  searchParams: Promise<{ projekt?: string; nachtrag?: string }>;
}) {
  const { projekt: projektId, nachtrag } = await searchParams;
  if (!projektId) notFound();

  const supabase = await serverKlient();
  const { data: projekt } = await supabase
    .from("projekt")
    .select("id, nummer, bezeichnung")
    .eq("id", projektId)
    .maybeSingle();
  if (!projekt) notFound();

  // Alles, was von dieser Baustelle dokumentiert ist, steht als Nachweis zur
  // Auswahl. Vier Wochen spaeter ist nichts davon mehr zu beschaffen.
  const { data: doku } = await supabase
    .from("dokumentation")
    .select("id, art, text, r2_key, erfasst_am")
    .eq("projekt_id", projektId)
    .order("erfasst_am", { ascending: false })
    .limit(40);

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href={`/projekte/${projektId}`}>← {projekt.bezeichnung}</Link>
        </p>
        <h1 className="seitentitel">Bedenkenanzeige</h1>
        <p className="zusatz">§ 4 Abs. 3 VOB/B</p>
      </div>

      <div className="karte">
        <p className="zusatz">
          Bedenken gegen die vorgesehene Art der Ausführung sind dem Auftraggeber
          <strong> unverzüglich</strong> und <strong>schriftlich</strong> mitzuteilen — möglichst
          vor Beginn der Arbeiten. Wer das versäumt, haftet für den Mangel mit, auch wenn er ihn
          nicht verursacht hat.
        </p>
      </div>

      <BedenkenFormular
        projektId={projektId}
        nachtragId={nachtrag ?? null}
        nachweise={(doku ?? []).map((d) => ({
          id: d.id,
          art: d.art,
          text: d.text,
          r2_key: d.r2_key,
          erfasst_am: d.erfasst_am,
        }))}
      />
    </>
  );
}
