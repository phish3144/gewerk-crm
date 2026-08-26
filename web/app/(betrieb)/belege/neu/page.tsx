import Link from "next/link";
import { redirect } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";
import { belegAnlegen } from "../aktionen";
import { BelegAnlegenFormular } from "./formular";

export default async function BelegNeu() {
  const supabase = await serverKlient();
  const { data: kunden } = await supabase.from("kunde").select("id, name").order("name");
  if (!kunden || kunden.length === 0) redirect("/kunden/neu");

  const { data: projekte } = await supabase
    .from("projekt")
    .select("id, bezeichnung, kunde_id")
    .order("bezeichnung");

  return (
    <>
      <div>
        <p className="zusatz">
          <Link href="/belege">← Belege</Link>
        </p>
        <h1 className="seitentitel">Angebot schreiben</h1>
        <p className="zusatz">Positionen kommen im nächsten Schritt dazu.</p>
      </div>
      <div className="karte">
        <BelegAnlegenFormular aktion={belegAnlegen} kunden={kunden} projekte={projekte ?? []} />
      </div>
    </>
  );
}
