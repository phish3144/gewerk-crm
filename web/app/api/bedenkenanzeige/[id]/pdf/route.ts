import { type NextRequest } from "next/server";
import { serverKlient } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { dateispeicher } from "@/lib/dateispeicher";
import { absatz, bild, fertig, linie, luecke, neueSeite, unterschriften } from "@/lib/pdf";

// Die Bedenkenanzeige als Schriftstueck. § 4 Abs. 3 VOB/B verlangt Schriftform;
// was hier herauskommt, wird ausgedruckt, unterschrieben und versendet.
//
// Erzeugt wird es bei jedem Abruf neu aus der Datenbank, nicht einmal abgelegt:
// solange die Anzeige Entwurf ist, soll das PDF dem Stand folgen. Nach dem
// Versand ist der Datensatz eingefroren, also auch das Ergebnis.
export async function GET(
  _anfrage: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;

  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) return new Response("Nicht angemeldet", { status: 401 });

  // Getrennte Abfragen statt einer verschachtelten Einbettung: PostgREST kann
  // das in einem Zug, aber die erzeugten Typen kippen dabei, und ein falsch
  // geschriebener Einbettungsausdruck laesst die ganze Abfrage stillschweigend
  // scheitern. Vier kleine Abfragen sind hier die ehrlichere Loesung.
  const supabase = await serverKlient();
  const { data: anzeige } = await supabase
    .from("bedenkenanzeige")
    // Ein einziges Zeichenkettenliteral, nicht zusammengesetzt: supabase-js
    // liest die Spaltenliste auf Typebene aus dem Literal. Eine mit + gebaute
    // Kette ist fuer den Typpruefer undurchsichtig, und das Ergebnis kommt als
    // Fehlerobjekt statt als Datensatz zurueck.
    .select("id, projekt_id, nachtrag_id, betreff, sachverhalt, folgen, erstellt_am, versendet_am, versendet_wie, versendet_an")
    .eq("id", id)
    .maybeSingle();
  if (!anzeige) return new Response("Nicht gefunden", { status: 404 });

  const { data: projekt } = await supabase
    .from("projekt")
    .select("nummer, bezeichnung, strasse, plz, ort, kunde(name, strasse, plz, ort)")
    .eq("id", anzeige.projekt_id)
    .maybeSingle();

  const { data: nachtrag } = anzeige.nachtrag_id
    ? await supabase.from("beleg").select("nummer").eq("id", anzeige.nachtrag_id).maybeSingle()
    : { data: null };

  const { data: betrieb } = await supabase
    .from("betrieb")
    .select("name, strasse, plz, ort, ust_id")
    .eq("id", aktiv.betrieb_id)
    .maybeSingle();

  const { data: verweise } = await supabase
    .from("bedenken_nachweis")
    .select("dokumentation(id, text, r2_key, erfasst_am)")
    .eq("bedenkenanzeige_id", id);

  const kunde = projekt?.kunde as unknown as {
    name: string;
    strasse: string | null;
    plz: string | null;
    ort: string | null;
  } | null;

  const deutsch = (w: string | null | undefined) =>
    w ? new Date(w).toLocaleDateString("de-DE") : "—";

  const f = await neueSeite();

  // Absender, klein und oben — wie auf einem Geschaeftsbrief.
  absatz(
    f,
    [betrieb?.name, betrieb?.strasse, [betrieb?.plz, betrieb?.ort].filter(Boolean).join(" ")]
      .filter(Boolean)
      .join(" · "),
    { groesse: 8.5, grau: true, abstand: 2 },
  );
  if (betrieb?.ust_id) {
    absatz(f, `USt-IdNr. ${betrieb.ust_id}`, { groesse: 8.5, grau: true, abstand: 18 });
  } else {
    luecke(f, 14);
  }

  // Empfaenger.
  absatz(f, kunde?.name ?? "Auftraggeber", { fett: true, abstand: 2 });
  if (kunde?.strasse) absatz(f, kunde.strasse, { abstand: 2 });
  if (kunde?.plz || kunde?.ort) {
    absatz(f, [kunde?.plz, kunde?.ort].filter(Boolean).join(" "), { abstand: 22 });
  } else {
    luecke(f, 20);
  }

  absatz(f, `${betrieb?.ort ? betrieb.ort + ", den " : ""}${deutsch(anzeige.erstellt_am)}`, {
    groesse: 9.5,
    grau: true,
    abstand: 14,
  });

  absatz(f, "Bedenkenanzeige nach § 4 Abs. 3 VOB/B", { groesse: 15, fett: true, abstand: 4 });
  absatz(f, anzeige.betreff, { groesse: 12, fett: true, abstand: 12 });

  absatz(
    f,
    [
      `Bauvorhaben: ${[projekt?.nummer, projekt?.bezeichnung].filter(Boolean).join(" · ")}`,
      projekt?.strasse
        ? `Ort: ${[projekt.strasse, projekt.plz, projekt.ort].filter(Boolean).join(", ")}`
        : null,
      nachtrag?.nummer ? `Zugehöriger Nachtrag: ${nachtrag.nummer}` : null,
    ]
      .filter(Boolean)
      .join("\n"),
    { groesse: 9.5, grau: true, abstand: 12 },
  );
  linie(f);

  absatz(f, "Sehr geehrte Damen und Herren,", { abstand: 10 });
  absatz(
    f,
    "gegen die vorgesehene Art der Ausführung melden wir hiermit unverzüglich und schriftlich " +
      "Bedenken an. Wir bitten um Ihre Entscheidung, bevor wir die Arbeiten fortsetzen.",
    { abstand: 12 },
  );

  absatz(f, "Sachverhalt", { fett: true, abstand: 4 });
  absatz(f, anzeige.sachverhalt, { abstand: 12 });

  if (anzeige.folgen) {
    absatz(f, "Mögliche Folgen", { fett: true, abstand: 4 });
    absatz(f, anzeige.folgen, { abstand: 12 });
  }

  // Die Fotos von der Baustelle. Sie sind der Grund, warum diese Anzeige
  // ueberhaupt etwas wert ist.
  // Ohne Dateispeicher entsteht das Schriftstueck trotzdem, nur ohne Bilder.
  // Eine Bedenkenanzeige, die wegen eines fehlenden Fotos gar nicht erst
  // herauskommt, waere die schlechtere Antwort.
  const eimer = dateispeicher();
  const nachweise = (verweise ?? [])
    .map((v) => v.dokumentation as unknown as { id: string; text: string | null; r2_key: string | null; erfasst_am: string } | null)
    .filter((d): d is NonNullable<typeof d> => Boolean(d));

  if (nachweise.length > 0) {
    absatz(f, "Nachweise", { fett: true, abstand: 6 });
    for (const n of nachweise) {
      absatz(f, `${deutsch(n.erfasst_am)}${n.text ? ` — ${n.text}` : ""}`, {
        groesse: 9.5,
        grau: true,
        abstand: 4,
      });
      // Der Schluessel traegt die betrieb_id im ersten Segment; ohne diese
      // Pruefung liesse sich ueber eine fremde Kennung ein fremdes Bild in ein
      // eigenes Schriftstueck holen.
      if (n.r2_key && eimer && n.r2_key.startsWith(`${aktiv.betrieb_id}/`)) {
        const objekt = await eimer.get(n.r2_key);
        if (objekt) {
          try {
            await bild(
              f,
              new Uint8Array(await objekt.arrayBuffer()),
              objekt.httpMetadata?.contentType ?? "image/jpeg",
            );
          } catch {
            // Ein Bild, das pdf-lib nicht lesen kann (etwa HEIC), darf das
            // ganze Schriftstueck nicht verhindern.
            absatz(f, "[Bild konnte nicht eingebettet werden]", {
              groesse: 9,
              grau: true,
              abstand: 4,
            });
          }
        }
      }
    }
    luecke(f, 8);
  }

  if (anzeige.versendet_am) {
    linie(f);
    absatz(
      f,
      `Versendet am ${deutsch(anzeige.versendet_am)} · ${anzeige.versendet_wie} · an ${anzeige.versendet_an}`,
      { groesse: 9, grau: true, abstand: 6 },
    );
  }

  unterschriften(f, `${betrieb?.name ?? "Auftragnehmer"} (Auftragnehmer)`, "Kenntnis genommen, Auftraggeber");

  const bytes = await fertig(f);
  const name = `Bedenkenanzeige-${(anzeige.betreff || "Anzeige").replace(/[^\w-]+/g, "-").slice(0, 40)}.pdf`;

  return new Response(bytes as unknown as BodyInit, {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `inline; filename="${name}"`,
      "Cache-Control": "private, no-store",
    },
  });
}
