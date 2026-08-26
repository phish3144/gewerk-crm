/* Prueft jede Vordergrund/Hintergrund-Paarung der Gestaltungstoken in beiden
   Modi gegen WCAG 2.1 und meldet sich mit Exit 1, wenn eine durchfaellt.
   Zusaetzlich wird geprueft, dass der Nacht-Block und der
   prefers-color-scheme-Block identisch sind - sie stehen doppelt im Stylesheet
   und laufen sonst still auseinander.

     node scripts/kontrast.mjs
*/
import { readFileSync } from "node:fs";

const css = readFileSync(new URL("../app/tokens.css", import.meta.url), "utf8");

const block = (selektor) => {
  const i = css.indexOf(selektor);
  if (i < 0) throw new Error(`Block ${selektor} nicht gefunden`);
  const auf = css.indexOf("{", i);
  const zu = css.indexOf("\n}", auf);
  const werte = {};
  for (const [, name, wert] of css.slice(auf, zu).matchAll(/--([\w-]+):\s*([^;]+);/g)) {
    werte[name] = wert.trim();
  }
  return werte;
};

const tag   = block(":root {");
const nacht = block('[data-theme="nacht"] {');
const medien= block(":root:not([data-theme=\"tag\"]) {");

// Der Nacht-Block steht zweimal im Stylesheet. Auseinanderlaufen faellt sonst
// erst auf, wenn ein Nutzer mit dunkel eingestelltem System etwas anderes sieht
// als einer, der den Umschalter benutzt hat.
const abweichend = Object.keys(nacht).filter(k => nacht[k] !== medien[k]);
const fehlend    = Object.keys(nacht).filter(k => !(k in medien));
if (abweichend.length || fehlend.length) {
  console.error("FEHLER Nacht-Block und prefers-color-scheme-Block weichen ab:");
  for (const k of abweichend) console.error(`  --${k}: "${nacht[k]}" vs "${medien[k]}"`);
  for (const k of fehlend)    console.error(`  --${k} fehlt im Medienblock`);
  process.exit(1);
}

// Eine Variable, die benutzt aber nie definiert wurde, faellt im Browser nicht
// auf - sie faellt still auf den Vorgabewert zurueck oder auf gar nichts.
{
  const basis = readFileSync(new URL("../app/basis.css", import.meta.url), "utf8");
  const vorschau = readFileSync(new URL("../app/vorschau.vorlage.html", import.meta.url), "utf8");
  const definiert = new Set([...css.matchAll(/--([\w-]+):/g)].map(m => m[1]));
  const benutzt = new Set(
    [...(css + basis + vorschau).matchAll(/var\(--([\w-]+)/g)].map(m => m[1])
  );
  const fehlend = [...benutzt].filter(v => !definiert.has(v));
  if (fehlend.length) {
    console.error("FEHLER benutzte, aber nicht definierte Variablen: " + fehlend.join(", "));
    process.exit(1);
  }
  console.log(`${benutzt.size} benutzte Variablen, alle definiert.`);
}

const lin = (c) => { c /= 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; };
const leuchtdichte = (hex) => {
  const h = hex.replace("#", "");
  const [r, g, b] = [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16));
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
};
const kontrast = (a, b) => {
  const [x, y] = [leuchtdichte(a), leuchtdichte(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};

// Schrift braucht 4.5:1, Bedienelemente und Datenmarken 3:1.
const PAARE = [
  ["schrift",             ["grund", "flaeche", "flaeche-gehoben"], 4.5],
  ["schrift-gedaempft",   ["grund", "flaeche", "flaeche-gehoben"], 4.5],
  ["schrift-schwach",     ["grund", "flaeche"],                    4.5],
  ["akzent-tinte",        ["akzent-flaeche"],                      4.5],
  ["akzent-schrift",      ["grund", "flaeche", "akzent-grund"],    4.5],
  ["material",            ["grund", "flaeche"],                    4.5],
  ["erfolg",              ["grund", "flaeche"],                    4.5],
  ["gefahr",              ["grund", "flaeche", "gefahr-grund"],    4.5],
  ["erfolg",              ["erfolg-grund"],                        4.5],
  // --rahmen ist eine Trennlinie zwischen Flaechen und traegt keine
  // Information; WCAG 1.4.11 greift dort nicht. Der Rand eines Bedienelements
  // schon - er ist das, woran man das Element ueberhaupt erkennt.
  ["rahmen-bedienelement", ["grund", "flaeche"],                   3.0],
];

// Datenfarben duerfen unter 3:1 liegen, aber nur mit Entlastung: jede Marke
// traegt eine direkte Beschriftung, Fremdleistung zusaetzlich eine Schraffur.
// Das ist die Auflage des Palettenpruefers ("relief required: visible labels").
// Sie steht hier ausdruecklich, damit niemand sie fuer eine stillschweigend
// gesenkte Grenze haelt.
const DATEN = ["daten-1", "daten-2", "daten-3", "daten-4"];
const ENTLASTUNG = "direkte Beschriftung auf jeder Marke, Schraffur bei Fremdleistung";

let fehler = 0;
for (const [name, werte] of [["Tag", tag], ["Nacht", nacht]]) {
  console.log(`\n${name}`);
  for (const [vorn, hinten, mindest] of PAARE) {
    for (const h of hinten) {
      const v = werte[vorn], g = werte[h];
      if (!v || !g || !v.startsWith("#") || !g.startsWith("#")) continue;
      const k = kontrast(v, g);
      const ok = k >= mindest;
      if (!ok) fehler++;
      console.log(
        `  ${ok ? "OK  " : "FAIL"} ${k.toFixed(2).padStart(5)}:1  (mind. ${mindest})  ` +
        `--${vorn} auf --${h}`
      );
    }
  }
}

// Jede Regel in basis.css, die Flaeche UND Tinte setzt, wird automatisch
// geprueft. Eine handgepflegte Liste haette den Fall uebersehen, der beim
// Ansehen des Rendings auffiel: die Stopp-Taste trug im Tagmodus dunkle Tinte
// auf dunkelrotem Grund (2,70:1). Der Fehler steckte nicht in einem Token,
// sondern in ihrer Kombination.
{
  const basis = readFileSync(new URL("../app/basis.css", import.meta.url), "utf8");
  const paare = [];
  const ungeprueft = [];
  for (const block of basis.split("}")) {
    const flaeche = block.match(/background:\s*var\(--([\w-]+)\)/);
    const tinte   = block.match(/(?:^|[\s;{])color:\s*var\(--([\w-]+)\)/);
    const zeilen  = block.split("{")[0].trim().split("\n").filter(z => !z.trim().startsWith("/*") && !z.trim().startsWith("*"));
    const wahl    = (zeilen[zeilen.length - 1] || "?").trim();
    if (block.includes("background:") && block.includes("color-mix")) {
      ungeprueft.push(wahl);
      continue;
    }
    if (flaeche && tinte) paare.push([wahl, tinte[1], flaeche[1]]);
  }

  console.log("\nKombinationen aus basis.css");
  for (const [name, werte] of [["Tag", tag], ["Nacht", nacht]]) {
    for (const [wahl, vorn, hinten] of paare) {
      const v = werte[vorn], g = werte[hinten];
      if (!v || !g || !v.startsWith("#") || !g.startsWith("#")) continue;
      const k = kontrast(v, g);
      const ok = k >= 4.5;
      if (!ok) fehler++;
      console.log(`  ${ok ? "OK  " : "FAIL"} ${k.toFixed(2).padStart(5)}:1  ${name.padEnd(5)} ${wahl}  --${vorn} auf --${hinten}`);
    }
  }
  if (ungeprueft.length) {
    console.log(`  nicht automatisch pruefbar (color-mix): ${[...new Set(ungeprueft)].join(", ")}`);
  }
}

// Datenfarben getrennt ausweisen: unter 3:1 ist eine Auflage, kein Fehlschlag.
console.log();
for (const [name, werte] of [["Tag", tag], ["Nacht", nacht]]) {
  const schwach = [];
  for (const d of DATEN) {
    for (const h of ["grund", "flaeche"]) {
      const k = kontrast(werte[d], werte[h]);
      if (k < 3.0) schwach.push(`--${d} auf --${h} (${k.toFixed(2)}:1)`);
    }
  }
  if (schwach.length) {
    console.log(`${name}: ${schwach.length} Datenfarb-Paarung(en) unter 3:1`);
    for (const z of schwach) console.log(`        ${z}`);
    console.log(`        zulaessig durch: ${ENTLASTUNG}`);
  } else {
    console.log(`${name}: alle Datenfarben ueber 3:1`);
  }
}

console.log();
if (fehler) { console.error(`${fehler} Paarung(en) unter der Grenze.`); process.exit(1); }
console.log("Alle Paarungen bestehen.");
