# Gestaltungsschicht

| Datei | Inhalt |
|---|---|
| `tokens.css` | Die 13 Farbrollen in Tag und Nacht, dazu Schrift, Flächengrößen, Abstände, Radien und die Datenfarben |
| `basis.css` | Dünne Bausteinschicht darauf: Tasten, Abzeichen, Eingabefeld, Karte, Titelzeile |
| `vorschau.html` | Dieselbe Seite in beiden Modi, mit funktionierendem Umschalter |

## Prüfen

```
node scripts/kontrast.mjs
```

Prüft drei Dinge und meldet sich mit Exit 1, wenn eines davon bricht:

1. **Blockgleichheit.** Der Nacht-Block steht zweimal im Stylesheet — einmal für
   `[data-theme="nacht"]`, einmal für `prefers-color-scheme: dark`. Laufen die
   beiden auseinander, sieht ein Nutzer mit dunkel eingestelltem System etwas
   anderes als einer, der den Umschalter benutzt hat.
2. **Vollständigkeit.** Eine benutzte, aber nie definierte Variable fällt im
   Browser nicht auf; sie fällt still auf nichts zurück.
3. **Kontrast.** Jede Vordergrund/Hintergrund-Paarung in beiden Modi, Schrift
   gegen 4,5:1 und Bedienelemente gegen 3:1.

## Zwei Entscheidungen, die nicht offensichtlich sind

**Signalgelb lässt sich nicht spiegeln.** `#FFC72C` erreicht auf Weiß nur
**1,56:1** und ist als Schrift unlesbar. Im Tag-Modus bleibt Gelb deshalb
*Fläche* — Tasten, Titelbalken, Diagramm, jeweils mit anthrazitfarbener Tinte
bei 11,3:1 — und weicht als *Schrift und Ikon* auf Bernstein `#8A6100` aus
(5,5:1). Das ist die einzige Rolle, die zwischen den Modi die Farbe wechselt
statt nur die Helligkeit.

**Zwei Rahmenfarben.** Eine Trennlinie zwischen Karten trägt keine Information
und darf leise sein; der Rand eines Eingabefelds ist dagegen das, woran man das
Bedienelement überhaupt erkennt, und muss 3:1 halten (WCAG 1.4.11). Ein einziger
Rahmen-Token hätte entweder zu laut oder nicht regelkonform sein müssen.

## Datenfarben

Bewusst getrennt von den UI-Akzenten. Signalgelb liegt bei OKLCH L 0,857 und
damit weit außerhalb des Bandes für Datenmarken. Die vier Stufen sind gegen den
Palettenprüfer validiert: im Band, Farbfehlsichtigkeit geprüft.

Fünf Paarungen liegen im Tag-Modus unter 3:1. Das ist zulässig, aber nur mit
Auflage: jede Marke trägt eine direkte Beschriftung, Fremdleistung zusätzlich
eine Schraffur. Der Prüfer weist diese Paarungen deshalb einzeln aus, statt die
Grenze stillschweigend zu senken.
