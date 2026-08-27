import { NextResponse, type NextRequest } from "next/server";
import { serverKlient } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";

// Nimmt entgegen, was auf der Baustelle erfasst wurde. Der Einstieg ist bewusst
// eng: nur diese drei Arten, nur diese Felder, und die Mandantenzuordnung kommt
// aus der Sitzung — nie aus der Nutzlast.
const ERLAUBT = {
  zeiteintrag: ["id", "projekt_id", "mitarbeiter_id", "beginn", "ende", "pause_minuten", "taetigkeit", "position_id", "nachweis_id"],
  dokumentation: ["id", "projekt_id", "art", "r2_key", "text", "aufmass", "erfasst_am", "erfasst_von"],
  materialentnahme: ["id", "projekt_id", "artikel_id", "bezeichnung", "menge", "einheit", "ek_preis", "position_id", "nachweis_id", "erfasst_am", "erfasst_von"],
} as const;

export async function POST(anfrage: NextRequest) {
  const koerper = (await anfrage.json().catch(() => null)) as
    | { art?: keyof typeof ERLAUBT; nutzlast?: Record<string, unknown> }
    | null;

  const art = koerper?.art;
  if (!art || !(art in ERLAUBT)) {
    return NextResponse.json({ fehler: "Unbekannte Art" }, { status: 400 });
  }

  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return NextResponse.json({ fehler: "Nicht angemeldet" }, { status: 401 });

  const roh = koerper?.nutzlast ?? {};
  const zeile: Record<string, unknown> = { betrieb_id: aktiv.betrieb_id };
  for (const feld of ERLAUBT[art]) {
    if (roh[feld] !== undefined && roh[feld] !== null && roh[feld] !== "") zeile[feld] = roh[feld];
  }
  if (!zeile["id"]) return NextResponse.json({ fehler: "Kennung fehlt" }, { status: 400 });

  const supabase = await serverKlient();

  // ignoreDuplicates: die Kennung kommt vom Geraet. Ein zweiter Versuch nach
  // einem abgerissenen Funkloch darf keinen zweiten Datensatz erzeugen.
  const { error } = await supabase.from(art).upsert(zeile, {
    onConflict: "id",
    ignoreDuplicates: true,
  });

  if (error) return NextResponse.json({ fehler: error.message }, { status: 400 });
  return NextResponse.json({ ok: true });
}
