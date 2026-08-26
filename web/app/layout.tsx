import type { Metadata, Viewport } from "next";
import { Barlow, Barlow_Condensed, IBM_Plex_Mono } from "next/font/google";
import "./global.css";

// Die drei Schriften des Entwurfs. next/font laedt sie beim Bauen herunter und
// liefert sie vom eigenen Server aus — auf der Baustelle gibt es keinen zweiten
// Netzzugriff, und es geht keine Adresse an Google.
const text = Barlow({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--schrift-text",
  display: "swap",
});
const anzeige = Barlow_Condensed({
  subsets: ["latin"],
  weight: ["600", "700"],
  variable: "--schrift-anzeige",
  display: "swap",
});
const zahl = IBM_Plex_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--schrift-zahl",
  display: "swap",
});

export const metadata: Metadata = {
  title: "gewerk",
  description: "CRM für das Handwerk",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // Die Farbe der Systemleiste folgt der Darstellung.
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FFFFFF" },
    { media: "(prefers-color-scheme: dark)", color: "#14161A" },
  ],
};

// Laeuft vor dem ersten Anstrich und setzt die gespeicherte Darstellung. Ohne
// das blitzt bei jeder Navigation kurz die helle Fassung auf, bevor React die
// dunkle setzt.
const themaFrueh = `
try {
  var t = localStorage.getItem("gewerk_thema");
  if (t === "tag" || t === "nacht") document.documentElement.setAttribute("data-theme", t);
} catch (e) {}
`;

export default function Wurzel({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de" className={`${text.variable} ${anzeige.variable} ${zahl.variable}`}>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themaFrueh }} />
        <style>{`:root {
          --schriftart-text: var(--schrift-text), "Helvetica Neue", Arial, sans-serif;
          --schriftart-anzeige: var(--schrift-anzeige), "Helvetica Neue", Arial, sans-serif;
          --schriftart-zahl: var(--schrift-zahl), ui-monospace, Menlo, monospace;
        }`}</style>
      </head>
      <body>{children}</body>
    </html>
  );
}
