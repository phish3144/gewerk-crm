import { redirect } from "next/navigation";
import { angemeldeteBenutzerin } from "@/lib/supabase/server";
import { meineZugehoerigkeiten } from "@/lib/betrieb";
import { serverKlient } from "@/lib/supabase/server";
import { EinrichtenFormular } from "./formular";

export default async function Einrichten() {
  const zugehoerigkeiten = await meineZugehoerigkeiten();
  if (zugehoerigkeiten.length > 0) redirect("/uebersicht");

  const person = await angemeldeteBenutzerin();

  // Steht schon eine benutzer-Zeile, ist der Name bekannt und muss nicht noch
  // einmal erfragt werden.
  const supabase = await serverKlient();
  const { data: eintrag } = await supabase
    .from("benutzer")
    .select("anzeigename")
    .eq("id", person?.id ?? "")
    .maybeSingle();

  const vorgeschlagen =
    eintrag?.anzeigename ??
    (person?.user_metadata?.["anzeigename"] as string | undefined) ??
    "";

  return (
    <main className="mitte">
      <div className="karte gestapelt">
        <div>
          <h1 className="seitentitel">Betrieb einrichten</h1>
          <p className="zusatz">
            Sie werden Inhaber und können danach Kolleginnen und Kollegen aufnehmen.
          </p>
        </div>
        <EinrichtenFormular
          nameBekannt={Boolean(eintrag?.anzeigename)}
          vorgeschlagenerName={vorgeschlagen}
        />
      </div>
    </main>
  );
}
