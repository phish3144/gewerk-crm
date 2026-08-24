#!/usr/bin/env python3
"""Prueft jedes Farbpaar der Design-Tokens gegen WCAG. Bricht ab, wenn eines
durchfaellt - die Werte in app/tokens.css sind damit nachgerechnet, nicht
behauptet."""
import sys

def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def _luminanz(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)

def kontrast(a, b):
    la, lb = _luminanz(a), _luminanz(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

TAG_GRUND, NACHT_GRUND = "#FFFFFF", "#17191B"

PAARE = [
    ("TAG   Schrift",           "#1A1C1E", TAG_GRUND,   4.5),
    ("TAG   Schrift gedaempft", "#5E656B", TAG_GRUND,   4.5),
    ("TAG   Schrift schwach",   "#878E94", TAG_GRUND,   3.0),
    ("TAG   Akzent-Schrift",    "#8A6100", TAG_GRUND,   4.5),
    ("TAG   Tinte auf Gelb",    "#17191B", "#FFC72C",   4.5),
    ("TAG   Erfolg",            "#12794F", TAG_GRUND,   4.5),
    ("TAG   Erfolg auf Grund",  "#12794F", "#E4F4EB",   4.5),
    ("TAG   Warnung auf Grund", "#8A6100", "#FDF3D6",   4.5),
    ("TAG   Gefahr",            "#B3261E", TAG_GRUND,   4.5),
    ("TAG   Gefahr auf Grund",  "#B3261E", "#FDECEA",   4.5),
    ("TAG   Material",          "#2F6FD0", TAG_GRUND,   4.5),
    ("NACHT Schrift",           "#F4F6F7", NACHT_GRUND, 4.5),
    ("NACHT Schrift gedaempft", "#98A1A8", NACHT_GRUND, 4.5),
    ("NACHT Schrift schwach",   "#6F7A81", NACHT_GRUND, 3.0),
    ("NACHT Akzent-Schrift",    "#FFC72C", NACHT_GRUND, 4.5),
    ("NACHT Erfolg",            "#5FD08A", NACHT_GRUND, 4.5),
    ("NACHT Erfolg auf Grund",  "#5FD08A", "#14301F",   4.5),
    ("NACHT Warnung auf Grund", "#FFC72C", "#3A2E10",   4.5),
    ("NACHT Gefahr",            "#FF6B5E", NACHT_GRUND, 4.5),
    ("NACHT Gefahr auf Grund",  "#FF6B5E", "#3D1B18",   4.5),
    ("NACHT Material",          "#7FB5FF", NACHT_GRUND, 4.5),
    # Der Beleg fuer die Kernentscheidung: Gelb als SCHRIFT auf Weiss faellt
    # durch. Deshalb weicht --akzent-schrift im Tag-Modus auf Bernstein aus.
    ("BELEG Gelb auf Weiss faellt durch", "#FFC72C", TAG_GRUND, 0.0),
]

durchgefallen = []
for name, vg, hg, mindest in PAARE:
    wert = kontrast(vg, hg)
    if wert < mindest:
        durchgefallen.append((name, wert, mindest))

if durchgefallen:
    for name, wert, mindest in durchgefallen:
        print(f"  FAIL {wert:5.2f}:1 (noetig {mindest})  {name}", file=sys.stderr)
    sys.exit(1)

gelb = kontrast("#FFC72C", TAG_GRUND)
print(f"  OK  {len(PAARE) - 1} Kontrastpaare bestehen "
      f"(Gelb auf Weiss liegt bei {gelb:.2f}:1 und ist deshalb keine Schriftfarbe)")
