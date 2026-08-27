import { expect, test } from "@playwright/test";
import { bildTaugt } from "../lib/pdf";

// Warum es diese Pruefung ueberhaupt gibt, gemessen und nicht vermutet:
//
//   gutes PNG        -> pdf-lib bettet es in  7 ms ein
//   abgeschnittenes  -> pdf-lib kehrt nie zurueck (ueber 20 s abgebrochen)
//
// Kein Fehler, keine Ausnahme - eine Endlosschleife. In einem Worker heisst
// das: die Anfrage haengt, bis die Laufzeit sie abraeumt. Ein halb
// hochgeladenes Foto legt damit die ganze Bedenkenanzeige lahm.
//
// Deshalb wird vorher geprueft, und deshalb steht diese Pruefung hier: wer
// bildTaugt() spaeter fuer ueberfluessig haelt, sieht hier, was sie verhindert.
const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAABUklEQVR4nOXQN3IDQQwEwNZ9ShFfz4ivOkUqGboza4DdiWYQofpjXdf1drmYNcvtcvF5vfb+o1sWmBlh+S6zIiy/x4wIy//DbAh3AMyF8BCAeRCeAjAHwksAxkd4C8DYCJsAGBdhMwBjIuwCYDyE3QCMhXAIgHEQDgMwBsIpAPIjnAYgN0IRAPIiFAMgJ0JRAPIhFAcgF0IVAPIgVAMgB0JVAOIjVAcgNkITAOIiNAMgJkJTAOIhNAcgFkIXAOIgdAMgBkJXAPojdAegL0IIAPohhAGgD0IoANojhAOgLUJIANohhAWgDUJoAOojhAegLkIKAOohpAGgDkIqAMojpAOgLEJKAMohpAWgDEJqAM4jpAfgHMIQABxHGAaAYwhDAbAfYTgA9iEMCcB2hGEB2IYwNADvEYYH4DXCFAA8R5gGgMcIUwFwjzAdAH8RpgTgB+ELpe3Cv2kZ+6kAAAAASUVORK5CYII=", "base64");

test("ein vollstaendiges PNG wird angenommen", () => {
  expect(bildTaugt(new Uint8Array(PNG), "image/png")).toBe(true);
});

test("ein abgeschnittenes PNG wird abgewiesen, bevor pdf-lib es sieht", () => {
  for (const anteil of [0.2, 0.5, 0.9]) {
    const kurz = new Uint8Array(PNG.subarray(0, Math.floor(PNG.length * anteil)));
    expect(bildTaugt(kurz, "image/png"), `${anteil * 100} % der Datei`).toBe(false);
  }
});

test("was gar kein Bild ist, wird abgewiesen", () => {
  expect(bildTaugt(new Uint8Array(Buffer.from("Das ist Text, kein Bild.")), "image/png")).toBe(false);
  expect(bildTaugt(new Uint8Array(Buffer.from("Das ist Text, kein Bild.")), "image/jpeg")).toBe(false);
  expect(bildTaugt(new Uint8Array(0), "image/png")).toBe(false);
});

test("JPEG braucht Anfangs- und Endkennung", () => {
  const gut = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0xff, 0xd9]);
  expect(bildTaugt(gut, "image/jpeg")).toBe(true);
  expect(bildTaugt(gut.subarray(0, 6), "image/jpeg"), "ohne Endkennung").toBe(false);
  expect(bildTaugt(gut.subarray(1), "image/jpeg"), "ohne Anfangskennung").toBe(false);
});
