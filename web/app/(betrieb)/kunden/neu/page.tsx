import Link from "next/link";
import { kundeAnlegen } from "../aktionen";
import { KundeFormular } from "../KundeFormular";

export default function KundeNeu() {
  return (
    <>
      <div>
        <p className="zusatz">
          <Link href="/kunden">← Kunden</Link>
        </p>
        <h1 className="seitentitel">Kunde anlegen</h1>
      </div>
      <div className="karte">
        <KundeFormular aktion={kundeAnlegen} knopf="Kunde anlegen" />
      </div>
    </>
  );
}
