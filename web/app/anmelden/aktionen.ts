"use server";

import { redirect } from "next/navigation";
import { serverKlient } from "@/lib/supabase/server";

export type Ergebnis = { fehler?: string; hinweis?: string };

// Supabase antwortet auf Englisch. Diese wenigen Faelle sind die, die eine
// Nutzerin wirklich zu sehen bekommt.
function uebersetzen(meldung: string): string {
  if (/invalid login credentials/i.test(meldung)) {
    return "E-Mail oder Passwort stimmt nicht.";
  }
  if (/email not confirmed/i.test(meldung)) {
    return "Die E-Mail-Adresse ist noch nicht bestätigt. Bitte zuerst den Link aus der Bestätigungsmail öffnen.";
  }
  if (/user already registered/i.test(meldung)) {
    return "Zu dieser E-Mail gibt es schon ein Konto. Bitte anmelden.";
  }
  if (/password should be at least/i.test(meldung)) {
    return "Das Passwort ist zu kurz.";
  }
  if (/email address .* is invalid/i.test(meldung)) {
    return "Diese E-Mail-Adresse akzeptiert der Anmeldedienst nicht.";
  }
  if (/rate limit|too many requests/i.test(meldung)) {
    return "Zu viele Versuche. Bitte einen Moment warten.";
  }
  return meldung;
}

export async function anmelden(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const email = String(daten.get("email") ?? "").trim();
  const passwort = String(daten.get("passwort") ?? "");
  const weiter = String(daten.get("weiter") ?? "") || "/";

  if (!email || !passwort) return { fehler: "Bitte E-Mail und Passwort eingeben." };

  const supabase = await serverKlient();
  const { error } = await supabase.auth.signInWithPassword({ email, password: passwort });
  if (error) return { fehler: uebersetzen(error.message) };

  redirect(weiter.startsWith("/") ? weiter : "/");
}

export async function registrieren(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const name = String(daten.get("name") ?? "").trim();
  const email = String(daten.get("email") ?? "").trim();
  const passwort = String(daten.get("passwort") ?? "");

  if (!name) return { fehler: "Bitte einen Namen eingeben." };
  if (!email || !passwort) return { fehler: "Bitte E-Mail und Passwort eingeben." };
  if (passwort.length < 8) return { fehler: "Das Passwort braucht mindestens 8 Zeichen." };

  const supabase = await serverKlient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password: passwort,
    options: { data: { anzeigename: name } },
  });
  if (error) return { fehler: uebersetzen(error.message) };

  // Zwei Faelle, je nach Einstellung des Projekts:
  //
  //   Bestaetigung aus  -> es kommt sofort eine Sitzung, es geht direkt weiter.
  //   Bestaetigung an   -> es kommt keine Sitzung, erst der Klick in der Mail.
  //
  // Beide werden bedient, damit ein Umlegen der Einstellung die Anwendung nicht
  // zerreisst.
  if (!data.session) {
    return {
      hinweis:
        "Fast fertig: Wir haben eine Bestätigungsmail an " +
        email +
        " geschickt. Nach dem Klick darin geht es hier weiter.",
    };
  }

  // Die benutzer-Zeile entsteht nicht von selbst. Ohne sie gibt es keine
  // Zugehoerigkeit und damit keinen Zugriff auf irgendetwas.
  const { error: kontoFehler } = await supabase.rpc("konto_anlegen", { p_anzeigename: name });
  if (kontoFehler) return { fehler: kontoFehler.message };

  redirect("/einrichten");
}
