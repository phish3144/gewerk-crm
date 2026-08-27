import { type NextRequest } from "next/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { rechnungsDaten } from "@/lib/rechnung";
import { zugferdXml } from "@/lib/zugferd";

// Der strukturierte Teil allein - zum Pruefen mit einem Validator und fuer
// Empfaenger, die nur die XML wollen.
export async function GET(_anfrage: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!(await aktiveZugehoerigkeit())) return new Response("Nicht angemeldet", { status: 401 });

  const daten = await rechnungsDaten(id);
  if (!daten) return new Response("Nicht gefunden", { status: 404 });

  return new Response(zugferdXml(daten), {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Content-Disposition": `inline; filename="${daten.nummer}.xml"`,
      "Cache-Control": "private, no-store",
    },
  });
}
