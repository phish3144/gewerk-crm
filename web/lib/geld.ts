// Geldbetraege und Mengen werden einheitlich deutsch dargestellt: Komma als
// Dezimalzeichen, Punkt als Tausendertrennung. Ohne feste Locale zeigt derselbe
// Beleg je nach Geraet 1,234.50 oder 1.234,50.
const euro = new Intl.NumberFormat("de-DE", {
  style: "currency",
  currency: "EUR",
  minimumFractionDigits: 2,
});

const menge = new Intl.NumberFormat("de-DE", {
  minimumFractionDigits: 0,
  maximumFractionDigits: 4,
});

export function alsEuro(wert: number | string | null | undefined): string {
  const z = typeof wert === "string" ? Number(wert) : (wert ?? 0);
  return euro.format(Number.isFinite(z) ? z : 0);
}

export function alsMenge(wert: number | string | null | undefined): string {
  const z = typeof wert === "string" ? Number(wert) : (wert ?? 0);
  return menge.format(Number.isFinite(z) ? z : 0);
}

export function alsDatum(wert: string | null | undefined): string {
  if (!wert) return "—";
  const d = new Date(wert);
  return Number.isNaN(d.getTime()) ? "—" : d.toLocaleDateString("de-DE");
}
