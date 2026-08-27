"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { serverKlient, angemeldeteBenutzerin } from "@/lib/supabase/server";
import { aktiveZugehoerigkeit } from "@/lib/betrieb";
import { fehlertext } from "@/lib/fehler";

// § 4 Abs. 3 VOB/B: Bedenken gegen die vorgesehene Art der Ausfuehrung sind
// dem Auftraggeber unverzueglich - moeglichst vor Beginn der Arbeiten -
// schriftlich mitzuteilen. Wer das versaeumt, haftet fuer den Mangel mit.
export async function bedenkenAnlegen(
  _stand: { fehler?: string } | undefined,
  formular: FormData,
): Promise<{ fehler?: string }> {
  const projektId = String(formular.get("projekt_id") ?? "");
  const betreff = String(formular.get("betreff") ?? "").trim();
  const sachverhalt = String(formular.get("sachverhalt") ?? "").trim();
  const folgen = String(formular.get("folgen") ?? "").trim();
  const nachtragId = String(formular.get("nachtrag_id") ?? "");

  if (!betreff || !sachverhalt) {
    return { fehler: "Betreff und Sachverhalt sind Pflicht — die Anzeige ist ein Schriftstück." };
  }

  const aktiv = await aktiveZugehoerigkeit();
  const person = await angemeldeteBenutzerin();
  if (!aktiv || !person) return { fehler: "Nicht angemeldet." };

  const supabase = await serverKlient();
  const { data, error } = await supabase
    .from("bedenkenanzeige")
    .insert({
      betrieb_id: aktiv.betrieb_id,
      projekt_id: projektId,
      nachtrag_id: nachtragId || null,
      betreff,
      sachverhalt,
      folgen: folgen || null,
      erstellt_von: person.id,
    })
    .select("id")
    .single();
  if (error) return { fehler: fehlertext(error) };

  // Die Nachweise der Baustelle haengen sich an: dieselben Fotos und Notizen,
  // die zu den ungeklaerten Buchungen gehoeren. Kopiert wird nichts.
  const nachweise = formular.getAll("nachweis").map(String).filter(Boolean);
  if (nachweise.length > 0) {
    await supabase.from("bedenken_nachweis").insert(
      nachweise.map((d) => ({
        betrieb_id: aktiv.betrieb_id,
        bedenkenanzeige_id: data.id,
        dokumentation_id: d,
      })),
    );
  }

  revalidatePath(`/projekte/${projektId}`);
  redirect(`/bedenken/${data.id}`);
}

export async function bedenkenAendern(
  _stand: { fehler?: string } | undefined,
  formular: FormData,
): Promise<{ fehler?: string }> {
  const id = String(formular.get("id") ?? "");
  const supabase = await serverKlient();
  const { error } = await supabase
    .from("bedenkenanzeige")
    .update({
      betreff: String(formular.get("betreff") ?? "").trim(),
      sachverhalt: String(formular.get("sachverhalt") ?? "").trim(),
      folgen: String(formular.get("folgen") ?? "").trim() || null,
    })
    .eq("id", id);
  if (error) return { fehler: fehlertext(error) };
  revalidatePath(`/bedenken/${id}`);
  return {};
}

// Der Versand friert den Datensatz ein. Das ist keine Formsache: der ganze
// Wert einer Bedenkenanzeige liegt darin, dass sie zu einem belegbaren
// Zeitpunkt so und nicht anders hinausgegangen ist. Der Trigger in 0024 laesst
// danach keine Aenderung mehr zu — auch nicht durch die Anwendung.
export async function bedenkenVersenden(
  _stand: { fehler?: string } | undefined,
  formular: FormData,
): Promise<{ fehler?: string }> {
  const id = String(formular.get("id") ?? "");
  const wie = String(formular.get("versendet_wie") ?? "").trim();
  const an = String(formular.get("versendet_an") ?? "").trim();

  if (!wie || !an) {
    return {
      fehler:
        "Weg und Empfänger gehören dazu. „Irgendwann per irgendwas“ ist kein Nachweis.",
    };
  }

  const supabase = await serverKlient();
  const { error } = await supabase
    .from("bedenkenanzeige")
    .update({ versendet_am: new Date().toISOString(), versendet_wie: wie, versendet_an: an })
    .eq("id", id);
  if (error) return { fehler: fehlertext(error) };

  revalidatePath(`/bedenken/${id}`);
  return {};
}
