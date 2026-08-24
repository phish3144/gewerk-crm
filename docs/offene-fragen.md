# Offene Fragen

Was **nicht** belegt ist. 37 von 129 recherchierten Behauptungen sind in der
adversarialen Verifikation durchgefallen — sie stehen bewusst nicht im Plan.

> Regel: Nichts aus dieser Liste wird implementiert, bevor es gegen eine
> Primärquelle geprüft ist.

---

## Blockierend — vor Schema-Freeze zu klären

### 1. Rechnungs-Datenmodell für Abschlagszahlungen und Einbehalte

**Alle** Aussagen dazu sind durchgefallen: § 14 VOB/B (Prüfbarkeit,
LV-Positionsreihenfolge, Aufmaß-Gegenzeichnung, REB-Format), § 16 VOB/B
(60-Tage-Frist, Verzug), § 17 VOB/B (5 % Vertragserfüllungs- und 5 %
Gewährleistungseinbehalt über 5 Jahre), § 13b UStG Reverse-Charge bei
Bauleistungen.

**Zu klären:** Wie werden Abschlagsrechnungen, Schlusszahlung mit Verrechnung
der Abschläge, Sicherheits- und Gewährleistungseinbehalte sowie
Reverse-Charge so modelliert, dass die erzeugte ZUGFeRD/XRechnung
EN-16931-konform validiert?

**Quellen:** VOB/B-Volltext, UStG, Steuerberater.
**Risiko:** Das ist der wahrscheinlichste Punkt, an dem eine handwerkstypische
Rechnung den KoSIT-Validator nicht besteht.

### 2. DATEV-Exportpfad

Sämtliche DATEV-Claims sind durchgefallen — auch die konkrete
EXTF-Spaltenspezifikation (Headerversion, Formatversion, Spaltenanzahl).
Verifiziert ist **nur**, dass das Prüfprogramm 2.2.3.0 und Musterdaten ohne
Login verfügbar sind.

**Zu klären:** Datei-Export (EXTF-Buchungsstapel) oder Cloud-API mit
Registrierungsprozess? Exakte Spaltenspezifikation aus der heruntergeladenen
Musterdatei `EXTF_Buchungsstapel.csv` ableiten.

**Risiko:** Steuerberater-Export ist bei der Zielgruppe faktisch Kaufkriterium.

### 3. GoBD Rz. 76 — Verzicht auf den PDF-Snapshot

Geteiltes Prüfvotum (2:1). Die Bedingung „jederzeit inhaltlich identisches
Mehrstück erzeugbar" ist der prüfungsrelevante Knackpunkt.

**Zu klären:** Schriftliche Bestätigung durch einen Steuerberater.
**Risiko:** Die gesamte PDF-lose Architektur hängt daran.

---

## Wichtig — vor Produktivsetzung

### 4. Reale Schreiblast

Nicht gemessen: Zeiterfassungseinträge, Belegpositionen und Doku-Datensätze
pro Betrieb und Tag. Ohne Lastmodell ist die Wahl von Postgres über D1 zwar
plausibel begründet, aber nicht quantitativ belegt.

### 5. DATANORM und UGL

Vollständig unbelegt: Spezifikation, Version, Bezugsstelle, Lizenzkosten,
Testdaten. Ebenso offen, welche Großhändler der Zielregion laut
IDS-Connect-Verzeichnis welche Version (2.0/2.3/2.5) unterstützen.

**Risiko:** Ohne das ist das Materialmodul nicht planbar.

### 6. DSGVO und Auftragsverarbeitung

Keine verifizierten Aussagen zu AV-Vertragspflichten, DPA-Lage bei Supabase
und Cloudflare, EU-Hosting-Anforderungen oder Verfahrensdokumentation.

**Risiko:** 96 % der Betriebe nennen Datenschutz als Hemmnis — das ist
verkaufsentscheidend, nicht nur juristisch relevant.

### 7. Supabase Free-Tier — Detailspezifikation

Die vollständige Free-Tier-Spezifikation (500 MB DB, 5 GB Egress, 1 GB
Storage, 50.000 MAU) ist **durchgefallen**. Verifiziert sind nur: Pausierung
nach 1 Woche, max. 2 aktive Projekte, keine Backups, 1 Tag Log-Retention,
50 MB max. Dateigröße.

---

## Nachrangig

### 8. PowerSync-Kosten

Preismodell, Free-Tier-Grenzen und Self-Hosting-Option nicht untersucht.
Erst relevant, wenn die Write-Queue nicht mehr ausreicht.

### 9. Wettbewerberpreise jenseits von plancraft und hero

ToolTime, Sage Handwerk, openHandwerk und Meisterwerk sind durchgefallen.
hero (59 €/22 €) stammt aus einer **Wettbewerber-Quelle** (Meisterwerk-Blog)
und ist ein 2026er Aktionspreis bei Jahresvertrag.

### 10. Ebenfalls durchgefallen — nicht weiterverwenden

- PowerSync-„Bucket"-Skalierung auf Millionen Zeilen
- RLS-Umgehung von Sub-Tabellen-RLS via `SECURITY DEFINER`
- Digitalkompetenz werde **vor** der App-Akzeptanz erworben (Kausalrichtung unbelegt)

---

## Verfallsdaten

Alle Cloudflare-, Vercel- und Supabase-Preise sind **USD netto, Abrufstand
August 2026**. Vercel weist Hobby-Werte ausdrücklich als unverbindliche
Richtwerte aus. Formatversionen (ZUGFeRD 2.5.x, XRechnung 3.0.2, IDS 2.5,
DATEV-Prüfprogramm 2.2.3.0, Mustangproject 2.25.0) altern schnell.

**Vor jeder Architekturentscheidung, die auf einer Zahl aus diesem Plan
beruht: Zahl neu prüfen.**
