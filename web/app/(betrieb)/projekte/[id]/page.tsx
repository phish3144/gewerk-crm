import Link from "next/link";
import { notFound } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { projektAendern } from "../aktionen";
import { ProjektFormular } from "../ProjektFormular";

export default async function ProjektBearbeiten({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ gespeichert?: string }>;
}) {
  const { id } = await params;
  const { gespeichert } = await searchParams;

  const supabase = await serverKlient();
  const { data: projekt } = await supabase.from("projekt").select("*").eq("id", id).maybeSingle();
  if (!projekt) notFound();

  const { data: kunden } = await supabase.from("kunde").select("id, name").order("name");

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href="/projekte">← Projekte</Link>
        </p>
        <h1 className="seitentitel">{projekt.bezeichnung}</h1>
      </div>

      <div className="reihe">
        <Link className="taste taste-sekundaer" href={`/projekte/${id}/doku`}>
          Baustellendoku
        </Link>
        <Link className="taste taste-sekundaer" href={`/bedenken/neu?projekt=${id}`}>
          Bedenken anzeigen
        </Link>
      </div>

      {gespeichert && (
        <p className="hinweis hinweis-freundlich" role="status">
          Gespeichert.
        </p>
      )}

      <div className="karte">
        <ProjektFormular
          aktion={projektAendern}
          kunden={kunden ?? []}
          werte={projekt}
          knopf="Änderungen speichern"
        />
      </div>
    </>
  );
}
