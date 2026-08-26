import { NextResponse, type NextRequest } from "next/server";
import { serverKlient } from "@/lib/supabase/server";
import { BETRIEB_KEKS } from "@/lib/betrieb";

// Abmelden ist ein POST, kein Link: ein GET liesse sich von fremder Seite aus
// ausloesen und wuerde Leute grundlos hinauswerfen.
export async function POST(anfrage: NextRequest) {
  const supabase = await serverKlient();
  await supabase.auth.signOut();

  const antwort = NextResponse.redirect(new URL("/anmelden", anfrage.url), { status: 303 });
  antwort.cookies.delete(BETRIEB_KEKS);
  return antwort;
}
