import { PDFDocument, StandardFonts, rgb, type PDFFont, type PDFPage } from "pdf-lib";

// Ein kleiner Satzbaukasten fuer die Schriftstuecke, die diese Anwendung
// erzeugt: Bedenkenanzeige jetzt, Rechnung in Schritt 8.
//
// Kein HTML-nach-PDF-Dienst und kein Browser im Hintergrund. Der Worker hat
// weder das eine noch das andere, und ein Schriftstueck, das vor Gericht
// zaehlt, soll nicht davon abhaengen, ob ein fremder Dienst gerade laeuft.
//
// Die Standardschrift Helvetica bringt WinAnsi mit: Umlaute, ß und § sind
// darin enthalten. Alles darueber hinaus wird ersetzt, statt pdf-lib mit einem
// nicht kodierbaren Zeichen abstuerzen zu lassen.
const RAND = 56;          // ~2 cm
const BREITE = 595.28;    // A4 hoch, in Punkt
const HOEHE = 841.89;

export type Satzflaeche = {
  dokument: PDFDocument;
  seite: PDFPage;
  y: number;
  normal: PDFFont;
  fett: PDFFont;
};

// WinAnsi kann nicht alles. Typografische Anfuehrungszeichen und Gedankenstriche
// kommen aus unseren eigenen Texten und wuerden sonst den Aufbau abbrechen.
const ERSATZ: Array<[RegExp, string]> = [
  [/[‘’‚]/g, "'"],
  [/[“”„]/g, '"'],
  [/[–—]/g, "-"],
  [/…/g, "..."],
  [/ /g, " "],
  [/−/g, "-"],
];

export function winansi(text: string): string {
  let t = text;
  for (const [muster, ersatz] of ERSATZ) t = t.replace(muster, ersatz);
  // Was danach noch uebrig ist und nicht kodierbar waere, faellt weg. Lieber
  // eine Luecke im Schriftstueck als gar kein Schriftstueck.
  return t.replace(/[^\x20-\x7E -ÿ\n\t]/g, "");
}

export async function neueSeite(): Promise<Satzflaeche> {
  const dokument = await PDFDocument.create();
  const normal = await dokument.embedFont(StandardFonts.Helvetica);
  const fett = await dokument.embedFont(StandardFonts.HelveticaBold);
  const seite = dokument.addPage([BREITE, HOEHE]);
  return { dokument, seite, y: HOEHE - RAND, normal, fett };
}

function platzSchaffen(f: Satzflaeche, hoehe: number) {
  if (f.y - hoehe < RAND) {
    f.seite = f.dokument.addPage([BREITE, HOEHE]);
    f.y = HOEHE - RAND;
  }
}

// Umbruch von Hand: pdf-lib bricht nicht selbst um.
export function umbrechen(text: string, schrift: PDFFont, groesse: number, breite: number): string[] {
  const zeilen: string[] = [];
  for (const absatz of winansi(text).split("\n")) {
    let zeile = "";
    for (const wort of absatz.split(/\s+/)) {
      const versuch = zeile ? `${zeile} ${wort}` : wort;
      if (schrift.widthOfTextAtSize(versuch, groesse) > breite && zeile) {
        zeilen.push(zeile);
        zeile = wort;
      } else {
        zeile = versuch;
      }
    }
    zeilen.push(zeile);
  }
  return zeilen;
}

export function absatz(
  f: Satzflaeche,
  text: string,
  { groesse = 10.5, fett = false, abstand = 6, grau = false } = {},
) {
  const schrift = fett ? f.fett : f.normal;
  const zeilenhoehe = groesse * 1.35;
  for (const zeile of umbrechen(text, schrift, groesse, BREITE - 2 * RAND)) {
    platzSchaffen(f, zeilenhoehe);
    f.seite.drawText(zeile, {
      x: RAND,
      y: f.y - groesse,
      size: groesse,
      font: schrift,
      color: grau ? rgb(0.42, 0.42, 0.42) : rgb(0.1, 0.1, 0.1),
    });
    f.y -= zeilenhoehe;
  }
  f.y -= abstand;
}

export function linie(f: Satzflaeche, abstand = 10) {
  platzSchaffen(f, abstand * 2);
  f.seite.drawLine({
    start: { x: RAND, y: f.y },
    end: { x: BREITE - RAND, y: f.y },
    thickness: 0.6,
    color: rgb(0.75, 0.75, 0.75),
  });
  f.y -= abstand;
}

export function luecke(f: Satzflaeche, hoehe: number) {
  platzSchaffen(f, hoehe);
  f.y -= hoehe;
}

// Taugen die Bytes ueberhaupt als Bild?
//
// Das ist keine Vorsichtsmassnahme auf Verdacht, sondern gemessen: pdf-lib
// laeuft bei abgeschnittenen PNG-Daten nicht in einen Fehler, sondern in eine
// Endlosschleife - der Aufruf kehrt nie zurueck. In einem Worker heisst das:
// die Anfrage haengt, bis die Laufzeit sie abraeumt. Ein halb hochgeladenes
// Foto wuerde damit die ganze Bedenkenanzeige lahmlegen.
//
// Geprueft wird deshalb vorher, und zwar das, was bei einem Abbruch tatsaechlich
// kaputt ist: Kennung am Anfang und ein vollstaendiger Aufbau bis zum Ende.
export function bildTaugt(daten: Uint8Array, typ: string): boolean {
  if (typ.includes("png")) {
    const kennung = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (daten.length < 57) return false;
    if (kennung.some((b, i) => daten[i] !== b)) return false;

    // Die Kette der Bloecke bis IEND durchlaufen. Passt eine Laenge nicht mehr
    // in den Puffer, ist die Datei abgeschnitten.
    const sicht = new DataView(daten.buffer, daten.byteOffset, daten.byteLength);
    let i = 8;
    while (i + 8 <= daten.length) {
      const laenge = sicht.getUint32(i);
      const art = String.fromCharCode(daten[i + 4]!, daten[i + 5]!, daten[i + 6]!, daten[i + 7]!);
      const naechster = i + 12 + laenge;
      if (naechster > daten.length) return false;
      if (art === "IEND") return true;
      i = naechster;
    }
    return false;
  }

  // JPEG: SOI am Anfang, EOI am Ende. Mehr braucht es nicht - der Parser von
  // pdf-lib liest nur die Kopfdaten und reicht den Rest durch.
  if (daten.length < 4) return false;
  if (daten[0] !== 0xff || daten[1] !== 0xd8) return false;
  return daten[daten.length - 2] === 0xff && daten[daten.length - 1] === 0xd9;
}

// Ein Bild, hoechstens halbe Satzbreite, Seitenverhaeltnis erhalten.
export async function bild(f: Satzflaeche, daten: Uint8Array, typ: string) {
  if (!bildTaugt(daten, typ)) {
    throw new Error("Die Bilddatei ist unvollstaendig oder kein Bild.");
  }

  const eingebettet = typ.includes("png")
    ? await f.dokument.embedPng(daten)
    : await f.dokument.embedJpg(daten);

  const maxBreite = (BREITE - 2 * RAND) / 2;
  const faktor = Math.min(1, maxBreite / eingebettet.width);
  const b = eingebettet.width * faktor;
  const h = eingebettet.height * faktor;

  platzSchaffen(f, h + 8);
  f.seite.drawImage(eingebettet, { x: RAND, y: f.y - h, width: b, height: h });
  f.y -= h + 8;
}

// Unterschriftsfeld: zwei Linien nebeneinander, darunter die Beschriftung.
export function unterschriften(f: Satzflaeche, links: string, rechts: string) {
  luecke(f, 34);
  platzSchaffen(f, 30);
  const mitte = BREITE / 2;
  for (const [x, breite, text] of [
    [RAND, mitte - RAND - 16, links],
    [mitte + 16, BREITE - RAND - mitte - 16, rechts],
  ] as Array<[number, number, string]>) {
    f.seite.drawLine({
      start: { x, y: f.y },
      end: { x: x + breite, y: f.y },
      thickness: 0.6,
      color: rgb(0.4, 0.4, 0.4),
    });
    f.seite.drawText(winansi(text), {
      x,
      y: f.y - 12,
      size: 8.5,
      font: f.normal,
      color: rgb(0.42, 0.42, 0.42),
    });
  }
  f.y -= 26;
}

export async function fertig(f: Satzflaeche): Promise<Uint8Array> {
  return await f.dokument.save();
}
