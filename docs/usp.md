# Wo der echte Mehrwert liegt

Recherche zur Frage: **was können wir einbauen, das die anderen nicht haben — und
das einem Handwerksbetrieb messbar Geld bringt?**

Konfidenzstufen wie im übrigen Plan: **hoch** = Primärquelle (Gesetzestext,
Behördenseite), **mittel** = Sekundärquelle oder Fachpresse, **niedrig** =
Einzelquelle oder Anbieterblog.

---

## 1. Was kein USP ist

Zuerst das Unangenehme. Vier Dinge, die naheliegen, sind bereits Standard und
taugen nicht zur Abgrenzung:

| Funktion | Wer hat es schon |
|---|---|
| **GAEB-Import/Export** (X83 → X84) | HERO, STREIT, WINWORKER, Hawepro, craftivo — durchgängig, auch bei den kleinen Anbietern |
| Mobile Zeiterfassung | alle |
| Angebot → Auftrag → Rechnung | alle |
| Baustellendoku mit Fotos | alle |

GAEB hatte ich als möglichen Vorsprung im Verdacht. Ist es nicht — es ist
Eintrittskarte. *(Konfidenz: hoch, direkt bei sechs Anbietern nachgesehen)*

Die Lücke liegt also **nicht** beim Funktionsumfang. Sie liegt bei dem, was
zwischen den Funktionen passiert.

---

## 2. Der Schmerz, der wirklich weh tut

> Der Betrieb leistet zuerst — kauft Material, setzt Leute ein, fährt zur
> Baustelle — und bekommt das Geld Wochen oder Monate später.

Dazu die Zahlen:

- **8,1 % des Branchenumsatzes** gehen durch Fehler verloren, rund 43 Mrd. €;
  je nach Erhebung 13–18,3 Mrd. € — „von jedem erwirtschafteten Euro über acht
  Cent". *(Konfidenz: mittel — Institut für Bauforschung bzw. BauInfoConsult,
  zitiert über Sekundärquelle, Primärstudie nicht selbst geprüft)*
- **Insolvenzen im Handwerk 2025: +13,3 % auf 4.950 Fälle** — höchster Stand
  seit über zehn Jahren; 25,5 % der Betriebe mit Umsatzrückgang.
  *(Konfidenz: mittel — Creditreform „Wirtschaftslage und Finanzierung im
  Handwerk 2025/26", über Fachpresse)*
- Ein großer Teil der Mehrleistungen wird **erbracht, aber nie vergütet** —
  weil die Abweichung nicht unverzüglich angezeigt oder nicht schriftlich
  vereinbart wurde. *(Konfidenz: mittel, mehrere unabhängige Fachquellen,
  keine Quote belastbar)*

Das ist kein Bedienbarkeitsproblem. Das ist ein **Geldflussproblem**, und keine
der geprüften Anwendungen greift es direkt an. Sie verwalten den Betrieb. Keine
sorgt dafür, dass er sein Geld bekommt.

**These:** Unser USP ist nicht „einfacher zu bedienen". Er ist

> **Die Software holt das Geld, das schon verdient ist.**

---

## 3. Vier Funktionen, nach Hebelwirkung

### 3.1 Nachtragswächter — der stärkste Hebel

**Das Problem.** Der Bauleiter sagt auf der Baustelle „machen Sie das noch mit".
Der Monteur macht es. Niemand schreibt etwas auf. Sechs Wochen später verweigert
der Auftraggeber die Zahlung, und er ist im Recht: § 4 Abs. 3 VOB/B verlangt die
Bedenkenanzeige **unverzüglich und schriftlich**. *(Konfidenz: hoch,
Gesetzes-/Vertragstext)*

**Was wir bauen.** Zeit und Material werden gegen eine **Position des
Leistungsverzeichnisses** gebucht. Bucht jemand auf etwas, wofür es keine
Position gibt, meldet das System es noch am selben Tag:

```
⚠  3,5 h auf "Baustelle Lindenstraße" ohne Position
   Das ist nicht beauftragt.
   → Nachtrag anlegen      → Bedenkenanzeige § 4 Abs. 3 VOB/B erzeugen
```

**Warum ausgerechnet wir.** Das Signal liegt bereits im Datenmodell:
`zeiteintrag.position_id` ist nullable — genau der Fall „gearbeitet, aber keiner
Position zugeordnet". Wir müssen es nur auswerten, nicht erst erfassen.

**Warum die anderen es schwer haben.** Es braucht Leistungsverzeichnis,
Zeiterfassung und Baustellendoku **in einem Modell**. Wer die Zeiterfassung als
App neben die Rechnungsschreibung gestellt hat, sieht die Lücke nicht.

---

### 3.2 Abschlagsautomatik nach § 632a BGB — der Liquiditätshebel

**Die Rechtslage.** Der Unternehmer kann Abschlag „in Höhe des Wertes der
erbrachten und vertragsgemäß geschuldeten Leistungen" verlangen. Der Wertzuwachs
beim Besteller ist **nicht mehr erforderlich** — das frühere Streitkriterium ist
entfallen. Nachzuweisen ist die Leistung durch „eine Aufstellung, die eine
rasche und sichere Beurteilung ermöglicht". *(Konfidenz: hoch, § 632a BGB)*

**Das Problem.** Genau diese Aufstellung ist Arbeit. Also wird der Abschlag zu
spät gestellt, zu niedrig angesetzt oder ganz vergessen — und der Betrieb
finanziert den Auftraggeber.

**Was wir bauen.** Das System kennt den Leistungsstand aus Zeiten, Material und
Positionsfortschritt. Es schlägt die Abschlagsrechnung von sich aus vor und
legt die geforderte Aufstellung gleich bei.

**Warum ausgerechnet wir.** Der schwierige Teil ist schon fertig und getestet:
Abschlagsabsetzung nach § 14 Abs. 5 UStG per Trigger erzwungen, die § 14c-Falle
abgesichert, Zahlungen und Anrechnung modelliert. Auf dieses Fundament einen
Vorschlag zu setzen ist wenig Arbeit — es *ohne* dieses Fundament zu tun ist
gefährlich, weil jeder Abschlag die Schlussrechnung berührt.

---

### 3.3 Fristenwächter — die Haftungsfallen an einem Ort

Ein Kalender für die Fristen, deren Versäumnis unmittelbar Geld kostet:

| Frist | Grundlage | Was passiert bei Versäumnis | Konfidenz |
|---|---|---|---|
| **Freistellungsbescheinigung**, i. d. R. 3 Jahre | § 48b EStG | Auftraggeber haftet für die nicht einbehaltenen 15 % — **unabhängig davon, ob er es wusste** | hoch |
| **Gewährleistung** 4 J (VOB) / 5 J (BGB) / 2 J (geringeres Risiko), ab Abnahme | § 13 VOB/B, § 634a BGB | Ansprüche verjähren; schriftliche Mängelanzeige setzt neue 2-Jahres-Frist | hoch |
| **Aufzeichnung der Arbeitszeit** binnen 7 Tagen, 2 Jahre aufbewahren | § 17 MiLoG (Bau) | Bußgeld bis 30.000 € | hoch |
| Sicherheitseinbehalt: Rückgabe/Ablösung | § 17 VOB/B | Geld bleibt beim Auftraggeber liegen | hoch |
| Skonto- und Zahlungsziele | Vertrag | Skonto verfällt, Verzug tritt nicht ein | hoch |

**Zur Freistellungsbescheinigung im Besonderen.** Dass es dafür eigenständige
Produkte am Markt gibt (z. B. „Freistellungsmanager"), ist der Beleg, dass die
CRM-Anbieter es nicht abdecken. Prüfen lässt sich eine Bescheinigung über das
**EIBE-Portal des BZSt** („Einzelabfrage FSB", mit Bundesland, Steuernummer und
Sicherheitsnummer) — das ist allerdings ein **Portal mit Registrierung, keine
offene Schnittstelle**. *(Konfidenz: hoch, BZSt-Seite geprüft)*

→ Wir können **nicht** automatisch abfragen. Wir können Sicherheitsnummer und
Ablaufdatum führen, rechtzeitig erinnern (90/30/14 Tage) und die Zahlung an
einen Subunternehmer **blockieren**, solange keine gültige Bescheinigung
hinterlegt ist. Das ist der ehrliche Funktionsumfang.

**Warum ausgerechnet wir.** Jede dieser Fristen hängt an einem Ereignis, das wir
ohnehin protokollieren — Abnahme, Festschreibung, Zahlung — und unser Journal
ist anfügend, also fälschungssicher.

---

### 3.4 Eingangsrechnungen — billig für uns, wertvoll für den Betrieb

Seit **1.1.2025** muss jedes Unternehmen E-Rechnungen empfangen können —
**ohne Übergangsfrist, unabhängig vom Umsatz**. Aufzubewahren ist das
elektronische Original (bei XRechnung die XML, bei ZUGFeRD das PDF mit
eingebetteten Daten). *(Konfidenz: hoch)*

Kleine Betriebe behelfen sich mit ELSTER-Viewer und einem Mailordner. Das ist
GoBD-seitig wacklig und fachlich wertlos.

**Was wir bauen.** ZUGFeRD/XRechnung einlesen, gegen Projekt und Bestellung
zuordnen, GoBD-konform im Original ablegen — und die Kosten landen dort, wo sie
hingehören: beim Projekt. Damit stimmt die Nachkalkulation zum ersten Mal.

**Aufwand für uns:** gering. Wir bauen den Formatteil ohnehin für den Versand.

---

## 4. Was wir bewusst nicht zuerst bauen

- **Datanorm / Open Masterdata / IDS-Connect** (Artikelstammdaten und Preise vom
  Großhandel). Fachlich wertvoll — plancraft fehlt z. B. eine eigene
  SHK-Artikeldatenbank — aber es ist Integrationsarbeit mit vielen Partnern.
  Open Masterdata löst Datanorm ab; wer neu baut, sollte gleich dort ansetzen.
  Späterer Burggraben, kein Startvorteil. *(Konfidenz: mittel)*
- **Werbung mit der Arbeitszeit-Novelle.** Der Referentenentwurf zur
  elektronischen Arbeitszeiterfassung ist im August 2026 **noch nicht
  beschlossen** — das BMAS nennt ihn selbst eine interne Arbeitsfassung.
  Betriebe bis 10 Beschäftigte sollen dauerhaft ausgenommen bleiben; unsere
  Zielgruppe 10–50 wäre also betroffen, *wenn* er kommt. Darauf lässt sich eine
  Funktion stützen, aber kein Verkaufsversprechen. Bindend sind schon heute das
  BAG-Urteil von 2022 und § 17 MiLoG — das genügt als Begründung.
  *(Konfidenz: hoch für den Status „Entwurf", mittel für die Details)*

---

## 5. Empfehlung

**Positionierung:** nicht „einfacher", sondern

> **Sie haben es gebaut. Wir sorgen dafür, dass es bezahlt wird.**

Drei Sätze, die ein Betriebsinhaber sofort versteht:

1. Wir sagen dir **am selben Tag**, wenn jemand etwas macht, das nicht beauftragt ist.
2. Wir schreiben deine Abschlagsrechnung, **bevor** du in Vorleistung erstickst.
3. Wir vergessen keine Frist, die dich Geld kostet.

**Reihenfolge:** 3.1 zuerst (größter Hebel, geringster Zusatzaufwand — das Signal
steckt schon im Modell), dann 3.2, dann 3.3, dann 3.4.

**Was noch zu prüfen ist.** Die Marktzahlen oben stammen aus Sekundärquellen.
Vor größerem Aufwand gehören drei bis fünf Gespräche mit echten Betrieben
geführt, mit genau einer Frage:

> „Wie viel Arbeit haben Sie letztes Jahr gemacht, die Sie nie abgerechnet
> haben — und warum nicht?"

Fällt die Antwort dünn aus, trägt diese Positionierung nicht und wir gehen
zurück auf Bedienbarkeit.

---

## Quellen

- [§ 632a BGB — Abschlagszahlungen](https://www.gesetze-im-internet.de/bgb/__632a.html)
- [BZSt — Bauleistungen, Freistellungsbescheinigung und EIBE-Portal](https://www.bzst.de/DE/Unternehmen/Bauleistungen/bauleistungen_node.html)
- [§ 48b EStG erklärt — Pflichten, Gültigkeit, Haftung](https://freistellungsmanager.de/blog/48b-estg-einfach-erklaert)
- [Margen-Erosion durch ineffizientes Nachtragsmanagement (Zahlen zu Fehlerkosten)](https://www.codana.de/wiki/handwerk/projektmanagement/abweichungen-vom-lv-nachtragsmanagement)
- [Handwerk verliert Geld: Nachträge sicher abrechnen mit VOB](https://www.vergabe24.de/blog/handwerk-nachtraege-sicher-abrechnen-vob/)
- [Zahlungsmoral drückt massiv auf die Liquidität der Betriebe](https://www.handwerk-magazin.de/umfrage-ergebnisse-zahlungsmoral-drueckt-massiv-auf-die-liquiditaet-der-betriebe-345405/)
- [Liquidität im Handwerk sichern — Vorfinanzierung](https://mein-handwerker-app.de/liquiditaet-handwerk-sichern-tipps/)
- [Aufzeichnungspflicht nach § 17 MiLoG — Branchen, Fristen, Bußgelder](https://www.avetiq.de/ratgeber/aufzeichnungspflicht-milog/)
- [Zeiterfassung im Baugewerbe — Pflicht für das Handwerk](https://123erfasst.de/arbeitszeiterfassung-pflicht/)
- [Reform des Arbeitszeitgesetzes — Stand des Referentenentwurfs](https://kliemt.blog/2026/05/13/gesetzesentwurf-zur-arbeitszeit-2026-was-jetzt-zu-erwarten-ist/)
- [Gewährleistung im Handwerk nach BGB und VOB](https://www.streit-software.de/wissen/gewaehrleistung-handwerker)
- [Gewährleistungsfristen nach VOB](https://www.vob.de/magazin/vob-gewaehrleistungsfristen/)
- [E-Rechnungen empfangen — digitaler Rechnungseingang im Handwerk](https://pds.de/unternehmen/blog/beitrag/e-rechnungen-empfangen)
- [E-Rechnung empfangen — alle Schritte bis zur Archivierung](https://www.fuer-gruender.de/wissen/unternehmen-fuehren/buchhaltung/rechnung/e-rechnung-empfangen/)
- [Open Masterdata löst Datanorm ab](https://v10.4master.de/open-masterdata-wird-zukuenftig-datanorm-abloesen/)
- [Open Masterdata und IDS Connect 2.5](https://www.shk-profi.de/news/shk_open_masterdata_und_ids_connect_2-5-3598858.html)
- [GAEB-Schnittstelle bei HERO](https://hero-software.de/features/schnittstellen/gaeb)
- [GAEB-Schnittstelle bei Hawepro (auch für Kleinstbetriebe)](https://hawepro.de/handwerkersoftware/funktionen/schnittstellen/gaeb/)
- [plancraft Erfahrungen und Grenzen](https://trusted.de/plancraft)
