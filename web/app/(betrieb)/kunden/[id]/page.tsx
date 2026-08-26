import Link from "next/link";
import { notFound } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { kundeAendern } from "../aktionen";
import { KundeFormular } from "../KundeFormular";

export default async function KundeBearbeiten({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ gespeichert?: string }>;
}) {
  const { id } = await params;
  const { gespeichert } = await searchParams;

  const supabase = await serverKlient();
  const { data: kunde } = await supabase.from("kunde").select("*").eq("id", id).maybeSingle();

  // Ein Kunde aus einem fremden Betrieb liefert durch die Policy schlicht nichts.
  // Fuer die Nutzerin ist das dasselbe wie "gibt es nicht" — und genau so soll
  // es aussehen, damit die Antwort nicht verraet, dass es ihn anderswo gibt.
  if (!kunde) notFound();

  const { count: projekte } = await supabase
    .from("projekt")
    .select("*", { count: "exact", head: true })
    .eq("kunde_id", id);

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href="/kunden">← Kunden</Link>
        </p>
        <h1 className="seitentitel">{kunde.name}</h1>
        <p className="zusatz">
          {projekte === 0 ? "Noch kein Projekt" : `${projekte} Projekte`}
        </p>
      </div>

      {gespeichert && (
        <p className="hinweis hinweis-freundlich" role="status">
          Gespeichert.
        </p>
      )}

      <div className="karte">
        <KundeFormular aktion={kundeAendern} werte={kunde} knopf="Änderungen speichern" />
      </div>
    </>
  );
}
