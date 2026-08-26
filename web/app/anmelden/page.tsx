import { AnmeldeFormular } from "./formular";

export default async function Anmelden({
  searchParams,
}: {
  searchParams: Promise<{ weiter?: string }>;
}) {
  const { weiter } = await searchParams;
  return (
    <main className="mitte">
      <div className="karte gestapelt">
        <div>
          <h1 className="seitentitel">Anmelden</h1>
          <p className="zusatz">Willkommen zurück.</p>
        </div>
        <AnmeldeFormular weiter={weiter ?? "/"} />
      </div>
    </main>
  );
}
