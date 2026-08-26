import { redirect } from "next/navigation";
import { meineZugehoerigkeiten } from "@/lib/betrieb";

// Die Weiche nach der Anmeldung. Wer noch zu keinem Betrieb gehoert, kann in
// der Anwendung nichts sehen — die Policies geben ihm nichts. Statt einer
// leeren Uebersicht kommt er zur Einrichtung.
export default async function Start() {
  const zugehoerigkeiten = await meineZugehoerigkeiten();
  redirect(zugehoerigkeiten.length === 0 ? "/einrichten" : "/uebersicht");
}
