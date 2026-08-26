// Die Design-Tokens haben genau eine Quelle: app/tokens.css im Wurzelverzeichnis.
// Dort liegen sie, weil scripts/kontrast.mjs und scripts/vorschau-bauen.mjs sie
// pruefen und die Entwurfsvorschau daraus bauen.
//
// Der Bundler soll nicht ueber die Projektgrenze greifen muessen, deshalb werden
// sie vor jedem dev- und build-Lauf hierher kopiert. Die Kopie ist erzeugt und
// wird nie von Hand bearbeitet - sie steht in .gitignore.
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const hier = dirname(fileURLToPath(import.meta.url));
const quelle = join(hier, "..", "..", "app");
const ziel = join(hier, "..", "app", "stile");

mkdirSync(ziel, { recursive: true });

const hinweis = `/* ERZEUGT - nicht bearbeiten.
   Quelle: app/%s im Wurzelverzeichnis. Aenderungen dort vornehmen,
   danach erzeugt "npm run dev" oder "npm run build" diese Datei neu. */\n\n`;

for (const datei of ["tokens.css", "basis.css"]) {
  const inhalt = readFileSync(join(quelle, datei), "utf8");
  writeFileSync(join(ziel, datei), hinweis.replace("%s", datei) + inhalt);
}

console.log("Stile uebernommen: tokens.css, basis.css");
