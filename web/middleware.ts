import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Oeffentlich erreichbar. Alles andere verlangt eine Anmeldung.
const offen = ["/anmelden", "/registrieren", "/abmelden"];

export async function middleware(anfrage: NextRequest) {
  let antwort = NextResponse.next({ request: anfrage });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll: () => anfrage.cookies.getAll(),
        setAll: (zuSetzen) => {
          for (const { name, value } of zuSetzen) anfrage.cookies.set(name, value);
          antwort = NextResponse.next({ request: anfrage });
          for (const { name, value, options } of zuSetzen) {
            antwort.cookies.set(name, value, options);
          }
        },
      },
    },
  );

  // getUser() und nicht getSession(): nur getUser() laesst den Auth-Server die
  // Signatur pruefen. getSession() glaubt dem Cookie — auf dem Server ist das
  // ein Wert, den der Aufrufer selbst gesetzt haben koennte.
  //
  // Dieser Aufruf erneuert nebenbei das abgelaufene Token und schreibt es ueber
  // setAll zurueck. Faellt er weg, wird jede Sitzung nach einer Stunde ungueltig.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const pfad = anfrage.nextUrl.pathname;
  const istOffen = offen.some((p) => pfad === p || pfad.startsWith(p + "/"));

  if (!user && !istOffen) {
    const ziel = anfrage.nextUrl.clone();
    ziel.pathname = "/anmelden";
    // Damit es nach der Anmeldung dort weitergeht, wo es unterbrochen wurde.
    if (pfad !== "/") ziel.searchParams.set("weiter", pfad);
    return NextResponse.redirect(ziel);
  }

  if (user && (pfad === "/anmelden" || pfad === "/registrieren")) {
    const ziel = anfrage.nextUrl.clone();
    ziel.pathname = "/";
    ziel.search = "";
    return NextResponse.redirect(ziel);
  }

  return antwort;
}

export const config = {
  // Alles ausser statischen Dateien und Bildern. Ohne diese Ausnahme laeuft die
  // Sitzungspruefung auch fuer jedes Symbol und jede Schriftdatei.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|woff2?)$).*)"],
};
