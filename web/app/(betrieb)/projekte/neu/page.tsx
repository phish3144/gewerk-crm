import Link from "next/link";
import { redirect } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { projektAnlegen } from "../aktionen";
import { ProjektFormular } from "../ProjektFormular";

export default async function ProjektNeu() {
  const supabase = await serverKlient();
  const { data: kunden } = await supabase.from("kunde").select("id, name").order("name");

  // Ohne Kunden gibt es nichts zu waehlen. Ein Formular mit leerer Liste waere
  // eine Sackgasse.
  if (!kunden || kunden.length === 0) redirect("/kunden/neu");

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href="/projekte">← Projekte</Link>
        </p>
        <h1 className="seitentitel">Projekt anlegen</h1>
      </div>
      <div className="karte">
        <ProjektFormular aktion={projektAnlegen} kunden={kunden} knopf="Projekt anlegen" />
      </div>
    </>
  );
}
