import Link from "next/link";
import { redirect } from "next/navigation";
import { aktiveZugehoerigkeit, meineZugehoerigkeiten } from "@/lib/betrieb";
import { ThemaUmschalter } from "@/komponenten/ThemaUmschalter";
import { BetriebWaehler } from "./BetriebWaehler";

// Welche Bereiche eine Rolle sieht. Das ist Bequemlichkeit, keine Sicherheit —
// die Policies entscheiden, nicht diese Liste. Ein Monteur, der eine
// Belegadresse von Hand aufruft, bekommt trotzdem nichts zu sehen.
const bereiche = {
  monteur: [
    { pfad: "/uebersicht", text: "Übersicht" },
    { pfad: "/zeit", text: "Zeiten" },
    { pfad: "/projekte", text: "Projekte" },
  ],
  buero: [
    { pfad: "/uebersicht", text: "Übersicht" },
    { pfad: "/zeit", text: "Zeiten" },
    { pfad: "/kunden", text: "Kunden" },
    { pfad: "/projekte", text: "Projekte" },
    { pfad: "/belege", text: "Belege" },
  ],
  inhaber: [
    { pfad: "/uebersicht", text: "Übersicht" },
    { pfad: "/zeit", text: "Zeiten" },
    { pfad: "/kunden", text: "Kunden" },
    { pfad: "/projekte", text: "Projekte" },
    { pfad: "/belege", text: "Belege" },
  ],
} as const;

export default async function BetriebsLayout({ children }: { children: React.ReactNode }) {
  const aktiv = await aktiveZugehoerigkeit();
  if (!aktiv) redirect("/einrichten");

  const alle = await meineZugehoerigkeiten();

  return (
    <div className="rahmen">
      <header className="kopf">
        <Link href="/uebersicht" className="kopf-marke">
          gewerk
        </Link>

        <nav className="navigation" aria-label="Bereiche">
          {bereiche[aktiv.rolle].map((b) => (
            <Link key={b.pfad} href={b.pfad}>
              {b.text}
            </Link>
          ))}
        </nav>

        <div className="kopf-rest">
          {alle.length > 1 ? (
            <BetriebWaehler alle={alle} aktiv={aktiv.betrieb_id} />
          ) : (
            <span className="zusatz">{aktiv.name}</span>
          )}
          <span className="abzeichen abzeichen-wartet">{aktiv.rolle}</span>
          <ThemaUmschalter />
          <form action="/abmelden" method="post">
            <button type="submit" className="taste taste-sekundaer">
              Abmelden
            </button>
          </form>
        </div>
      </header>

      <main className="inhalt">{children}</main>
    </div>
  );
}
