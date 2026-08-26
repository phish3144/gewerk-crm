/* Baut aus der Vorlage eine eigenstaendige Vorschauseite: die beiden
   Stylesheets werden eingebettet, damit die Datei auch allein funktioniert.
   Relative Pfade brechen, sobald die Seite ohne ihre Nachbardateien geoeffnet
   wird - genau das ist beim ersten Versand passiert.

     node scripts/vorschau-bauen.mjs
*/
import { readFileSync, writeFileSync } from "node:fs";

const pfad = (n) => new URL(`../app/${n}`, import.meta.url);
let html = readFileSync(pfad("vorschau.vorlage.html"), "utf8");

for (const datei of ["tokens.css", "basis.css"]) {
  const marke = `<link rel="stylesheet" href="${datei}">`;
  if (!html.includes(marke)) throw new Error(`Verweis auf ${datei} nicht gefunden`);
  html = html.replace(marke, `<style>\n/* ${datei} */\n${readFileSync(pfad(datei), "utf8")}</style>`);
}

// Google Fonts bleibt als Verweis: die Schriften laedt der Browser selbst,
// und ein Ausfall faellt auf die Ersatzschriften zurueck statt die Seite zu brechen.
if (/<link rel="stylesheet" href="(?!https)/.test(html)) {
  throw new Error("Es steht noch ein relativer Stylesheet-Verweis in der Datei");
}

writeFileSync(pfad("vorschau.html"), html);
console.log(`app/vorschau.html gebaut, ${(html.length / 1024).toFixed(1)} kB, keine relativen Verweise`);
