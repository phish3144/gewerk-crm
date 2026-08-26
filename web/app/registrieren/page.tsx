import { RegistrierFormular } from "./formular";

export default function Registrieren() {
  return (
    <main className="mitte">
      <div className="karte gestapelt">
        <div>
          <h1 className="seitentitel">Konto anlegen</h1>
          <p className="zusatz">Danach richten Sie Ihren Betrieb ein.</p>
        </div>
        <RegistrierFormular />
      </div>
    </main>
  );
}
