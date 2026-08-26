"use client";

import { createBrowserClient } from "@supabase/ssr";
import { umgebung } from "@/lib/umgebung";

// Im Browser laeuft jeder Zugriff mit dem Token der angemeldeten Person und
// damit als Rolle `authenticated`. Ohne Anmeldung greift die Rolle `anon` — die
// seit Migration 0017 kein Recht auf kein Objekt mehr hat.
export function browserKlient() {
  return createBrowserClient(umgebung.supabaseUrl, umgebung.supabaseSchluessel);
}
