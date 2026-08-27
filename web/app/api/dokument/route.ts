import { NextResponse, type NextRequest } from "next/server";
import { serverKlient } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { dateispeicher } from "@/lib/dateispeicher";

// Dateien gehen durch den Worker in den R2-Bucket, nicht ueber eine im Browser
// erzeugte Signatur: dafuer braeuchte der Client S3-Zugangsdaten, und die
// duerfen ihn nie erreichen. Der Worker hat die Bindung, der Browser hat sie
// nicht — das ist der ganze Unterschied.
//
// Der Objektschluessel traegt die betrieb_id als erstes Segment. Damit ist an
// jedem Objekt ablesbar, wem es gehoert, ohne die Datenbank zu befragen.
const HOECHSTENS = 12 * 1024 * 1024;
const ERLAUBTE_TYPEN = ["image/jpeg", "image/png", "image/webp", "image/heic"];

export async function POST(anfrage: NextRequest) {
  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return NextResponse.json({ fehler: "Nicht angemeldet" }, { status: 401 });

  const formular = await anfrage.formData();
  const datei = formular.get("datei");
  const projekt_id = String(formular.get("projekt_id") ?? "");

  if (!(datei instanceof File)) {
    return NextResponse.json({ fehler: "Keine Datei" }, { status: 400 });
  }
  if (datei.size > HOECHSTENS) {
    return NextResponse.json({ fehler: "Die Datei ist zu groß (max. 12 MB)." }, { status: 400 });
  }
  if (!ERLAUBTE_TYPEN.includes(datei.type)) {
    return NextResponse.json({ fehler: `Dateityp ${datei.type} ist nicht vorgesehen.` }, { status: 400 });
  }

  // Gehoert das Projekt zum aktiven Betrieb? Die Policy beantwortet das, indem
  // sie nichts liefert, wenn es nicht so ist.
  const supabase = await serverKlient();
  const { data: projekt } = await supabase
    .from("projekt")
    .select("id")
    .eq("id", projekt_id)
    .maybeSingle();
  if (!projekt) return NextResponse.json({ fehler: "Projekt nicht gefunden" }, { status: 404 });

  const endung = datei.type === "image/png" ? "png" : datei.type === "image/webp" ? "webp" : "jpg";
  const schluessel = `${aktiv.betrieb_id}/${projekt_id}/${crypto.randomUUID()}.${endung}`;

  const eimer = dateispeicher();
  if (!eimer) {
    return NextResponse.json(
      { fehler: "Der Dateispeicher ist in dieser Umgebung nicht angebunden." },
      { status: 503 },
    );
  }

  await eimer.put(schluessel, await datei.arrayBuffer(), {
    httpMetadata: { contentType: datei.type },
  });

  return NextResponse.json({ r2_key: schluessel });
}

// Auslieferung ausschliesslich durch den Worker. Der Bucket ist nicht
// oeffentlich; wer die Datei sehen will, muss angemeldet sein UND zu dem
// Betrieb gehoeren, dessen Kennung im Schluessel steht.
export async function GET(anfrage: NextRequest) {
  const schluessel = anfrage.nextUrl.searchParams.get("k");
  if (!schluessel) return new NextResponse("Kein Schlüssel", { status: 400 });

  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return new NextResponse("Nicht angemeldet", { status: 401 });

  // Das erste Segment ist die betrieb_id. Ein Schluessel aus einem fremden
  // Betrieb wird abgewiesen, bevor der Bucket ueberhaupt gefragt wird.
  if (!schluessel.startsWith(`${aktiv.betrieb_id}/`)) {
    return new NextResponse("Nicht gefunden", { status: 404 });
  }

  const eimer = dateispeicher();
  if (!eimer) return new NextResponse("Kein Dateispeicher", { status: 503 });

  const objekt = await eimer.get(schluessel);
  if (!objekt) return new NextResponse("Nicht gefunden", { status: 404 });

  return new NextResponse(objekt.body as unknown as BodyInit, {
    headers: {
      "Content-Type": objekt.httpMetadata?.contentType ?? "application/octet-stream",
      // Privat und kurz: die Adresse soll nicht in fremden Zwischenspeichern liegen.
      "Cache-Control": "private, max-age=300",
    },
  });
}
