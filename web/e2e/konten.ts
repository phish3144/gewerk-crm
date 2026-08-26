import { createClient } from "@supabase/supabase-js";

// Zwei Pruefkonten in zwei getrennten Betrieben. example.com ist von der IANA
// fuer genau diesen Zweck reserviert und gehoert niemandem.
//
// Das Anlegen ist idempotent: besteht das Konto schon, wird angemeldet statt
// angelegt. Damit laesst sich der Lauf beliebig oft wiederholen.
export const KONTEN = {
  a: { email: "pruefer-a@example.com", passwort: "PruefPasswort-A-2026", name: "Anna Pruefer", betrieb: "Pruefbetrieb A" },
  b: { email: "pruefer-b@example.com", passwort: "PruefPasswort-B-2026", name: "Bruno Pruefer", betrieb: "Pruefbetrieb B" },
} as const;

// Erst beim Aufruf lesen, nicht beim Import: sonst stehen die Werte noch nicht,
// weil die .env.local zu diesem Zeitpunkt noch nicht geladen ist.
export function klient() {
  const url = process.env["NEXT_PUBLIC_SUPABASE_URL"];
  const schluessel = process.env["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"];
  if (!url || !schluessel) {
    throw new Error("NEXT_PUBLIC_SUPABASE_* fehlen — web/.env.local anlegen.");
  }
  return createClient(url, schluessel, { auth: { persistSession: false } });
}

// Die Anmeldeeinstellungen des Projekts sind oeffentlich abfragbar. Sie hier zu
// pruefen kostet einen Aufruf und erspart die Suche nach der Ursache: die
// Meldungen von GoTrue ("Email signups are disabled") sagen nicht, welcher
// Schalter im Dashboard gemeint ist.
async function einstellungenPruefen() {
  const url = process.env["NEXT_PUBLIC_SUPABASE_URL"]!;
  const schluessel = process.env["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"]!;
  const antwort = await fetch(`${url}/auth/v1/settings`, { headers: { apikey: schluessel } });
  const e = (await antwort.json()) as {
    disable_signup?: boolean;
    mailer_autoconfirm?: boolean;
    external?: { email?: boolean };
  };

  if (e.external?.email !== true) {
    throw new Error(
      "Die E-Mail-Anmeldung ist im Supabase-Projekt abgeschaltet.\n" +
        "  Dashboard -> Authentication -> Sign In / Providers -> Email einschalten.\n" +
        "  Darin zusaetzlich \"Confirm email\" ausschalten, sonst braucht jedes\n" +
        "  Pruefkonto einen Klick in einer Bestaetigungsmail.",
    );
  }
  if (e.disable_signup === true) {
    throw new Error(
      "Registrierungen sind im Supabase-Projekt gesperrt.\n" +
        "  Dashboard -> Authentication -> Sign In / Providers -> \"Allow new users to sign up\".",
    );
  }
  if (e.mailer_autoconfirm !== true) {
    throw new Error(
      "\"Confirm email\" ist eingeschaltet. Die Pruefkonten koennen dann nicht\n" +
        "  ohne Postfach angelegt werden.\n" +
        "  Dashboard -> Authentication -> Sign In / Providers -> Email -> Confirm email aus.",
    );
  }
}

export async function kontoBereitstellen(konto: (typeof KONTEN)[keyof typeof KONTEN]) {
  await einstellungenPruefen();
  const supabase = klient();

  const anmeldung = await supabase.auth.signInWithPassword({
    email: konto.email,
    password: konto.passwort,
  });

  if (anmeldung.error) {
    const neu = await supabase.auth.signUp({ email: konto.email, password: konto.passwort });
    if (neu.error) throw new Error(`Konto ${konto.email}: ${neu.error.message}`);
    if (!neu.data.session) {
      throw new Error(
        `Konto ${konto.email} braucht eine E-Mail-Bestaetigung. ` +
          `Fuer die Pruefkonten muss "Confirm email" im Projekt ausgeschaltet sein.`,
      );
    }
  }

  // konto_anlegen ist idempotent, betrieb_gruenden nicht — deshalb erst pruefen,
  // ob schon eine Zugehoerigkeit besteht.
  await supabase.rpc("konto_anlegen", { p_anzeigename: konto.name });

  const { data: zugehoerig } = await supabase.from("benutzer_betrieb").select("betrieb_id");
  if (!zugehoerig || zugehoerig.length === 0) {
    const { error: gruendung } = await supabase.rpc("betrieb_gruenden", { p_name: konto.betrieb });
    if (gruendung) throw new Error(`Betrieb fuer ${konto.email}: ${gruendung.message}`);
  }

  return supabase;
}
