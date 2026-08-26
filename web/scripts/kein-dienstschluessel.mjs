// Die gesamte Mandantentrennung haengt daran, dass jeder Zugriff als Rolle
// `authenticated` laeuft und damit durch RLS. Ein service_role-Schluessel im
// Browser-Bundle haette RLS vollstaendig ausgehebelt - und zwar unbemerkt, weil
// die Anwendung dann *besser* funktioniert, nicht schlechter.
//
// Deshalb ist das eine Pruefung und keine Konvention.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const hier = dirname(fileURLToPath(import.meta.url));
const wurzel = join(hier, "..");

// Ein service_role-JWT traegt "role":"service_role" im Nutzlast-Teil; die
// neueren geheimen Schluessel beginnen mit sb_secret_. Gesucht wird beides,
// dazu der Name der Umgebungsvariablen.
const verboten = [
  { muster: /sb_secret_[A-Za-z0-9_-]{10,}/, was: "geheimer Schluessel (sb_secret_...)" },
  { muster: /service_role/, was: 'die Zeichenkette "service_role"' },
  { muster: /SUPABASE_SERVICE_ROLE_KEY/, was: "der Name des Dienstschluessels" },
];

const zuPruefen = [join(wurzel, ".next", "static"), join(wurzel, ".open-next")];
const funde = [];
let geprueft = 0;

function durchgehen(pfad) {
  let eintraege;
  try {
    eintraege = readdirSync(pfad);
  } catch {
    return; // Verzeichnis nicht vorhanden - dann gibt es dort auch nichts zu finden.
  }
  for (const name of eintraege) {
    const voll = join(pfad, name);
    if (statSync(voll).isDirectory()) {
      durchgehen(voll);
      continue;
    }
    if (!/\.(js|mjs|cjs|json|txt|html)$/.test(name)) continue;
    geprueft += 1;
    const inhalt = readFileSync(voll, "utf8");
    for (const { muster, was } of verboten) {
      if (muster.test(inhalt)) {
        funde.push(`${voll.replace(wurzel + "/", "")}: ${was}`);
      }
    }
  }
}

for (const ort of zuPruefen) durchgehen(ort);

if (geprueft === 0) {
  console.error("FEHLER  Nichts geprueft - erst bauen, dann pruefen.");
  process.exit(1);
}
if (funde.length > 0) {
  console.error("FEHLER  Dienstschluessel im ausgelieferten Code:");
  for (const f of funde) console.error("        " + f);
  process.exit(1);
}
console.log(`OK  ${geprueft} ausgelieferte Dateien, kein Dienstschluessel`);
