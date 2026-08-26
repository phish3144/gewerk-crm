import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { umgebung } from "@/lib/umgebung";

// Server-Klient fuer Server Components, Server Actions und Route Handler.
export async function serverKlient() {
  const kekse = await cookies();

  return createServerClient(umgebung.supabaseUrl, umgebung.supabaseSchluessel, {
    cookies: {
      getAll: () => kekse.getAll(),
      setAll: (zuSetzen) => {
        try {
          for (const { name, value, options } of zuSetzen) {
            kekse.set(name, value, options);
          }
        } catch {
          // In einer Server Component darf nicht geschrieben werden. Das ist
          // kein Fehler: die Middleware erneuert die Sitzung bei jeder Anfrage,
          // hier faellt nur der Schreibversuch weg.
        }
      },
    },
  });
}

// Die angemeldete Person. Bewusst getUser() und nicht getSession(): getSession()
// liest das Cookie, ohne die Signatur beim Auth-Server zu pruefen — auf dem
// Server ist das ein manipulierbarer Wert.
export async function angemeldeteBenutzerin() {
  const supabase = await serverKlient();
  const { data } = await supabase.auth.getUser();
  return data.user;
}
