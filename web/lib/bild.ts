"use client";

// Fotos werden vor dem Anstellen verkleinert. Ein Handyfoto hat heute leicht
// 6 MB; auf der Baustelle sind das Minuten Funk und am Monatsende Geld.
// Zielgroesse rund 500 KB bei 1600 px Kante.
export async function verkleinern(datei: File): Promise<Blob> {
  if (!datei.type.startsWith("image/")) return datei;
  try {
    const bild = await createImageBitmap(datei);
    const kante = 1600;
    const faktor = Math.min(1, kante / Math.max(bild.width, bild.height));
    const breite = Math.round(bild.width * faktor);
    const hoehe = Math.round(bild.height * faktor);

    const flaeche = new OffscreenCanvas(breite, hoehe);
    const stift = flaeche.getContext("2d");
    if (!stift) return datei;
    stift.drawImage(bild, 0, 0, breite, hoehe);
    return await flaeche.convertToBlob({ type: "image/jpeg", quality: 0.82 });
  } catch {
    // Kein OffscreenCanvas, kein createImageBitmap: dann eben im Original.
    return datei;
  }
}
