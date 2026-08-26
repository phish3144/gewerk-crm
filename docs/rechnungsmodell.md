<!-- Erzeugt aus einem adversarial gepruefen Recherchelauf, 26.08.2026.
     48 Aussagen, 43 nach dreifacher Gegenpruefung belegt, 5 verworfen.
     Zugelassene Primaerquellen waren ausschliesslich: gesetze-im-internet.de,
     der amtliche VOB/B-Text, bundesfinanzministerium.de (BMF-Schreiben, UStAE),
     KoSIT/xeinkauf (XRechnung, EN 16931) und FeRD (ZUGFeRD).
     Kanzlei-Blogs und Softwareanbieter waren ausdruecklich nicht zugelassen. -->

# Rechnungsmodell für Abschlagszahlungen, Einbehalte und Reverse Charge

Stand: 26.08.2026 · Zielsystem: Postgres/Supabase · Zielformat: EN 16931 (XRechnung 3.0.2 / ZUGFeRD)

Alle Aussagen in diesem Dokument sind an einen Paragrafen, einen amtlichen Erlasstext oder einen Feldbezeichner der Spezifikation gebunden. Modellierungsentscheidungen, die über die Quellenlage hinausgehen, sind mit **[ANNAHME]** gekennzeichnet.

---

## 1. Was gesichert ist

### 1.1 Die Abschlagsrechnung ist umsatzsteuerlich eine normale Rechnung

| Regel | Fundstelle |
|---|---|
| Für Rechnungen über noch nicht ausgeführte Leistungen gelten § 14 Abs. 1 bis 4 UStG „sinngemäß" — also derselbe Pflichtangabenkatalog wie bei jeder anderen Rechnung. | § 14 Abs. 5 Satz 1 UStG: *„Vereinnahmt der Unternehmer das Entgelt oder einen Teil des Entgelts für eine noch nicht ausgeführte Lieferung oder sonstige Leistung, gelten die Absätze 1 bis 4 sinngemäß."* |
| Aus dem Beleg **muss hervorgehen**, dass über eine Voraus- oder Anzahlung abgerechnet wird. | UStAE 14.8 Abs. 1 Satz 1: *„Aus Rechnungen über Zahlungen vor Ausführung der Leistung muss hervorgehen, dass damit Voraus- oder Anzahlungen … abgerechnet werden, z. B. durch Angabe des voraussichtlichen Zeitpunkts der Leistung."* |
| Ob über das gesamte Entgelt oder nur einen Teil abgerechnet wird, ist unerheblich. Eine Vorausrechnung über 100 % ist zulässig und lässt zusätzliche Anzahlungsrechnungen entfallen. | UStAE 14.8 Abs. 1 Satz 2; Abs. 6: *„Zusätzliche Rechnungen über Voraus- oder Anzahlungen entfallen dann."* |
| Statt des Leistungszeitpunkts ist der Zeitpunkt der **Vereinnahmung** anzugeben, sofern er feststeht und vom Ausstellungsdatum abweicht. | § 14 Abs. 4 Satz 1 Nr. 6 UStG, 2. Halbsatz: *„… in den Fällen des Absatzes 5 Satz 1 den Zeitpunkt der Vereinnahmung des Entgelts oder eines Teils des Entgelts, sofern der Zeitpunkt der Vereinnahmung feststeht und nicht mit dem Ausstellungsdatum der Rechnung übereinstimmt"* |
| Ersatzweise: voraussichtlicher Zeitpunkt, Kalendermonat, vereinbarter Zeitraum — oder der Hinweis, dass noch kein Zeitpunkt vereinbart ist. | § 31 Abs. 4 UStDV; UStAE 14.8 Abs. 4 Sätze 3–5 |
| An die Stelle des Entgelts tritt das vereinnahmte (Teil-)Entgelt; der darauf entfallende Steuerbetrag ist auszuweisen. | § 14 Abs. 4 Satz 1 Nr. 7 und Nr. 8 UStG; UStAE 14.8 Abs. 4 Sätze 6–7 |
| Die Gegenstände bzw. die Art der Leistung müssen **schon im Zeitpunkt der Anzahlung genau bestimmt** sein. | UStAE 14.8 Abs. 4 Satz 2 |

### 1.2 Steuerentstehung: Vereinnahmung, nicht Rechnungsdatum

| Regel | Fundstelle |
|---|---|
| Bei Anzahlungen entsteht die Steuer mit Ablauf des Voranmeldungszeitraums der **Vereinnahmung**. | § 13 Abs. 1 Nr. 1 Buchst. a Satz 4 UStG; UStAE 13.5 Abs. 1 Satz 1 |
| Vereinnahmt ist bei Überweisung grundsätzlich mit **Gutschrift auf dem Bankkonto**. | UStAE 13.6 Abs. 1 Satz 3: *„Als Zeitpunkt der Vereinnahmung gilt bei Überweisungen auf ein Bankkonto grundsätzlich der Zeitpunkt der Gutschrift."* |
| Davon strikt zu trennen: die **Teilleistung**. Sie liegt vor, wenn für bestimmte Teile einer wirtschaftlich teilbaren Leistung das Entgelt **gesondert vereinbart** wurde; dann entsteht die Steuer mit Ausführung. | § 13 Abs. 1 Nr. 1 Buchst. a Sätze 2–3 UStG |
| Bei Sollversteuerung entsteht die Steuer mit Ablauf des Voranmeldungszeitraums der Leistungsausführung — unabhängig von der Zahlung. | § 13 Abs. 1 Nr. 1 Buchst. a Satz 1 UStG |
| Eine Abschlagsrechnung darf **vor** der Zahlung ausgestellt werden. | UStAE 14.8 Abs. 5 Satz 3: *„Rechnungen mit gesondertem Steuerausweis können schon erteilt werden, bevor eine Voraus- oder Anzahlung vereinnahmt worden ist."* |
| Zahlt der Kunde **weniger** als angefordert, entsteht die Steuer nur auf den vereinnahmten Betrag — eine Rechnungsberichtigung ist **nicht** erforderlich. | UStAE 14.8 Abs. 5 Sätze 4–5 |
| Wird die berechnete Anzahlung **gar nicht** geleistet, tritt **keine** Besteuerung nach § 14c Abs. 2 UStG ein. | UStAE 14.8 Abs. 2 Satz 1 |

### 1.3 Schlussrechnung: Endrechnung, Restrechnung, § 14c-Falle

| Regel | Fundstelle |
|---|---|
| In der **Endrechnung** sind die vorher vereinnahmten Teilentgelte **und die darauf entfallenden Steuerbeträge** abzusetzen, wenn über die Teilentgelte Rechnungen mit gesondertem Steuerausweis erteilt wurden. | § 14 Abs. 5 Satz 2 UStG; UStAE 14.8 Abs. 7 Satz 1 |
| Diese Pflicht bleibt bestehen, auch wenn der Unternehmer die Anzahlungsrechnungen nachträglich **widerruft oder zurücknimmt**. | UStAE 14.8 Abs. 9 Satz 1 |
| Darstellungsvarianten der Absetzung (gleichwertig): einzeln je Anzahlung; Summe der Teilentgelte + Summe der Steuerbeträge; Bruttobeträge mit zusätzlich angegebener enthaltener Steuer; Verzicht auf den Steuerbetrag des Restentgelts, wenn die Gesamtsteuer angegeben ist. | UStAE 14.8 Abs. 7 Sätze 2–4 |
| Vereinfachungen: bloße Zusatzangabe statt Absetzung; Anhang mit ausdrücklichem Hinweis; gesonderte Zusammenstellung mit wechselseitigem Hinweis. | UStAE 14.8 Abs. 8 Nrn. 1–3 |
| **E-Rechnung:** Alle Pflichtangaben müssen im **strukturierten Teil** stehen; ein bloßer Verweis auf eine unstrukturierte Anlage genügt nicht. | BMF-Schreiben v. 15.10.2025, Rn. 35: *„Ein bloßer Verweis in den strukturierten Daten auf eine Anlage, in der die Rechnungspflichtangaben in unstrukturierter Form enthalten sind, genügt nicht, da dann keine elektronische Verarbeitung möglich ist."* |
| Für E-Rechnungsfälle verweist der UStAE auf Rn. 47/48 des BMF-Schreibens v. 15.10.2024 (BStBl I S. 1320). | UStAE 14.8 Abs. 7 Satz 5 |
| **Sanktion:** Werden die Teilentgelte und die darauf entfallenden Steuerbeträge nicht **oder nur teilweise** abgesetzt, schuldet der Unternehmer den in der Endrechnung ausgewiesenen **gesamten** Steuerbetrag; der auf die Anzahlungen entfallende Teil wird **zusätzlich** nach § 14c Abs. 1 UStG geschuldet. | UStAE 14.8 Abs. 10 Sätze 1–3 |
| Der Kunde darf nur die auf das Restentgelt entfallende Vorsteuer ziehen. | UStAE 14.8 Abs. 10 Satz 4 |
| Heilung durch nachträglich berichtigte Endrechnung, § 17 Abs. 1 UStG entsprechend — also **ex nunc** im Berichtigungszeitraum. | UStAE 14.8 Abs. 10 Satz 5; § 14c Abs. 1 Satz 2 UStG |
| Die 14c-Steuer entsteht **im Zeitpunkt der Ausgabe der Rechnung**. | § 13 Abs. 1 Nr. 3 UStG |
| **Alternative Restrechnung:** Statt einer Endrechnung kann über das restliche Entgelt abgerechnet werden. Darin sind die vereinnahmten Teilentgelte und die darauf entfallenden Steuerbeträge **nicht anzugeben**. Zulässig ist die Zusatzangabe des Gesamtentgelts **ohne Steuer** mit Absetzung der Teilentgelte **ohne Steuer**. | UStAE 14.8 Abs. 11 Sätze 1–3 |

### 1.4 Vertragsregime: VOB/B ist AGB, nicht Gesetz

| Regel | Fundstelle |
|---|---|
| Die VOB/B gilt nur bei wirksamer Einbeziehung (Hinweis + Kenntnisnahmemöglichkeit + Einverständnis). | § 305 Abs. 2 BGB |
| Das BGB privilegiert die VOB/B von der Inhaltskontrolle nur, wenn sie *„in der jeweils zum Zeitpunkt des Vertragsschlusses geltenden Fassung ohne inhaltliche Abweichungen insgesamt einbezogen ist"* — und nur gegenüber Unternehmern/jPöR. | § 310 Abs. 1 Satz 3 BGB |
| Aktuelle Fassung: VOB/B Ausgabe 2016, Bekanntmachung v. 07.01.2016 (BAnz AT 19.01.2016 B3; ber. BAnz AT 01.04.2016 B1). | Bekanntmachung a.a.O. |
| Ohne VOB/B: Abschläge nach § 632a Abs. 1 BGB; Fälligkeit der Schlussrechnung nach Abnahme + prüffähiger Schlussrechnung, Prüfbarkeitseinwendung binnen 30 Tagen. | § 632a Abs. 1 BGB; § 650g Abs. 4 BGB |

### 1.5 Abschlagszahlungen und Prüfbarkeit nach VOB/B

| Regel | Fundstelle |
|---|---|
| Abschlagszahlungen sind auf Antrag zu gewähren **in Höhe des Wertes der nachgewiesenen vertragsgemäßen Leistungen einschließlich des ausgewiesenen, darauf entfallenden Umsatzsteuerbetrages**. Nachweis durch prüfbare Aufstellung. | § 16 Abs. 1 Nr. 1 VOB/B |
| Als Leistung gelten auch eigens angefertigte/bereitgestellte Bauteile und auf der Baustelle angelieferte Stoffe — **nur** wenn Eigentum übertragen oder Sicherheit gegeben ist. | § 16 Abs. 1 Nr. 1 Satz 3 VOB/B |
| Fälligkeit: **21 Tage nach Zugang der Aufstellung**. | § 16 Abs. 1 Nr. 3 VOB/B |
| Abschlagszahlungen gelten **nicht als Abnahme** von Teilen der Leistung und sind ohne Einfluss auf die Haftung. | § 16 Abs. 1 Nr. 4 VOB/B |
| Schlusszahlung: fällig alsbald nach Prüfung, **spätestens 30 Tage nach Zugang der Schlussrechnung**; Verlängerung auf höchstens 60 Tage nur bei sachlicher Rechtfertigung **und** ausdrücklicher Vereinbarung (kumulativ). | § 16 Abs. 3 Nr. 1 VOB/B |
| Präklusion: Werden Einwendungen gegen die Prüfbarkeit **unter Angabe der Gründe** nicht fristgerecht erhoben, kann sich der AG nicht mehr auf fehlende Prüfbarkeit berufen. | § 16 Abs. 3 Nr. 1 Satz 3 VOB/B |
| Verzögert sich die Prüfung, ist das **unbestrittene Guthaben als Abschlagszahlung sofort** zu zahlen. | § 16 Abs. 3 Nr. 1 Satz 5 VOB/B |
| Zahlungsverzug tritt **ohne Nachfristsetzung spätestens 30 Tage** nach Zugang der Rechnung oder der Aufstellung ein (verlängerbar auf höchstens 60 Tage). | § 16 Abs. 5 Nr. 3 VOB/B; Zinsen § 288 Abs. 2 BGB, Basiszinssatz § 247 BGB |
| Ausschlusswirkung: vorbehaltlose Annahme der Schlusszahlung schließt Nachforderungen aus — **nur** bei schriftlicher Unterrichtung **und** Hinweis auf die Ausschlusswirkung. | § 16 Abs. 3 Nr. 2 VOB/B |
| Der endgültige schriftliche Ablehnungsbescheid steht der Schlusszahlung gleich; früher gestellte unerledigte Forderungen werden ebenfalls ausgeschlossen, wenn nicht nochmals vorbehalten. | § 16 Abs. 3 Nr. 3 und Nr. 4 VOB/B |
| Fristen: Vorbehalt binnen **28 Tagen**; hinfällig, wenn nicht binnen **weiterer 28 Tage** (beginnend am Tag nach Ablauf der ersten Frist) eine prüfbare Rechnung eingereicht oder der Vorbehalt eingehend begründet wird. | § 16 Abs. 3 Nr. 5 VOB/B |
| Die Ausschlussfristen gelten **nicht** für Richtigstellung wegen **Aufmaß-, Rechen- und Übertragungsfehlern**. | § 16 Abs. 3 Nr. 6 VOB/B |
| Prüfbarkeit formal: übersichtliche Aufstellung, **Reihenfolge der Posten einhalten**, **Bezeichnungen aus den Vertragsbestandteilen verwenden**, Mengenberechnungen/Zeichnungen/Belege **beifügen**; Nachträge besonders kenntlich machen, auf Verlangen getrennt abrechnen. | § 14 Abs. 1 VOB/B |
| Feststellungen möglichst **gemeinsam**; für später schwer feststellbare Leistungen sind gemeinsame Feststellungen rechtzeitig zu beantragen. | § 14 Abs. 2 VOB/B |
| Schlussrechnung einzureichen: **12 Werktage** nach Fertigstellung bei Ausführungsfrist bis 3 Monate, **+ 6 Werktage je weitere 3 Monate**. Reicht der AN trotz angemessener Frist keine prüfbare Rechnung ein, darf der AG sie auf Kosten des AN selbst aufstellen. | § 14 Abs. 3 und Abs. 4 VOB/B |

### 1.6 Nachträge

| Regel | Fundstelle |
|---|---|
| **Geänderte Leistung:** Ändern sich durch Anordnung des AG die Preisgrundlagen einer im Vertrag vorgesehenen Leistung, ist ein neuer Preis **zu vereinbaren** (zweiseitig). Die Vereinbarung **soll** vor der Ausführung getroffen werden. Keine Ankündigungspflicht. | § 2 Abs. 5 VOB/B; Anordnungsrecht § 1 Abs. 3 VOB/B |
| **Zusätzliche Leistung:** Anspruch auf besondere Vergütung, aber der AN **muss** den Anspruch ankündigen, **bevor** er mit der Ausführung beginnt. Vergütung = Grundlagen der Preisermittlung der Vertragsleistung **plus** besondere Kosten. Die Vereinbarung ist nur „möglichst" vorher zu treffen. | § 2 Abs. 6 Nr. 1 und Nr. 2 VOB/B |
| **Ohne Auftrag:** Eigenmächtige Leistungen werden **nicht** vergütet und sind auf Verlangen zu beseitigen. Vergütung nur bei nachträglicher Anerkennung **oder** bei Notwendigkeit **und** mutmaßlichem Willen **und** unverzüglicher Anzeige (kumulativ). Preisbildung dann nach Abs. 5 oder 6. | § 2 Abs. 8 Nr. 1 und Nr. 2 VOB/B |
| **BGB-Bauvertrag:** Nach 30 Tagen ergebnisloser Verhandlung kann der Besteller die Änderung **in Textform** anordnen. Vergütung nach den **tatsächlich erforderlichen Kosten** zzgl. Zuschlägen für AGK, Wagnis und Gewinn; die fortgeschriebene Urkalkulation begründet nur eine **Vermutung**. | § 650b Abs. 2 Satz 1 BGB; § 650c Abs. 1 Satz 1 und Abs. 2 Satz 2 BGB |
| Vor der Einigung dürfen **80 %** der angebotenen Mehrvergütung in Abschlagszahlungen angesetzt werden; Überzahlungen sind zurückzugewähren und **ab Eingang beim Unternehmer zu verzinsen**. | § 650c Abs. 3 Sätze 1 und 3 BGB |

### 1.7 Einbehalte und Sicherheiten

| Regel | Fundstelle |
|---|---|
| Gegenforderungen können einbehalten werden; **andere Einbehalte nur in den im Vertrag und in den gesetzlichen Bestimmungen vorgesehenen Fällen**. | § 16 Abs. 1 Nr. 2 VOB/B |
| Die **10 v. H.** sind die maximale **Kürzungsrate je einzelner Zahlung**, nicht die Höhe der Sicherheit: *„… so darf er jeweils die Zahlung um höchstens 10 v. H. kürzen, bis die vereinbarte Sicherheitssumme erreicht ist."* Die **Sicherheitssumme selbst legt die VOB/B nicht fest** — sie ergibt sich allein aus dem Vertrag. | § 17 Abs. 6 Nr. 1 Satz 1 VOB/B |
| Bei Abrechnung **ohne Umsatzsteuer nach § 13b UStG** bleibt die Umsatzsteuer bei der Berechnung des Sicherheitseinbehalts **unberücksichtigt**. | § 17 Abs. 6 Nr. 1 Satz 2 VOB/B |
| Der einbehaltene Betrag ist mitzuteilen und binnen **18 Werktagen** nach dieser Mitteilung auf ein Sperrkonto einzuzahlen. | § 17 Abs. 6 Nr. 1 Satz 3 VOB/B |
| Sperrkonto = **Und-Konto**, gemeinsame Verfügung; **Zinsen stehen dem Auftragnehmer zu**. | § 17 Abs. 5 VOB/B |
| Zahlt der AG nicht rechtzeitig ein, kann der AN eine angemessene Nachfrist setzen; verstreicht auch diese, kann er **sofortige Auszahlung** verlangen und **braucht keine Sicherheit mehr zu leisten**. | § 17 Abs. 6 Nr. 3 VOB/B |
| Die Sicherheit dient **zwei** Zwecken: vertragsgemäße Ausführung **und** Mängelansprüche. | § 17 Abs. 1 Nr. 2 VOB/B |
| Rückgabe Vertragserfüllungssicherheit: zum vereinbarten Zeitpunkt, **spätestens nach Abnahme und Stellung der Sicherheit für Mängelansprüche**. | § 17 Abs. 8 Nr. 1 VOB/B |
| Rückgabe Mängelanspruchssicherheit: **nach Ablauf von 2 Jahren**, sofern kein anderer Zeitpunkt vereinbart. | § 17 Abs. 8 Nr. 2 VOB/B |
| **Umsatzsteuerlich mindert der Einbehalt nichts.** Entgelt ist alles, was der Unternehmer *„erhält oder erhalten soll"* — der einbehaltene Teil ist geschuldet, nur noch nicht gezahlt. | § 10 Abs. 1 Satz 2 UStG; § 13 Abs. 1 Nr. 1 Buchst. a Satz 1 UStG |
| Steuerberichtigung wegen Uneinbringlichkeit nur, *„soweit dem Unternehmer nachweislich die Absicherung dieser Gewährleistungsansprüche durch Gestellung von Bankbürgschaften im Einzelfall nicht möglich war und er dadurch das Entgelt insoweit für einen Zeitraum von über zwei bis fünf Jahren noch nicht vereinnahmen kann"*. | § 17 Abs. 2 Nr. 1 UStG; UStAE 17.1 Abs. 5 Satz 3 |
| Auch dann muss die ursprüngliche Rechnung — **ausdrücklich auch die E-Rechnung** — **nicht** berichtigt werden. Die Berichtigung erfolgt im Zeitraum, in dem die Änderung eingetreten ist. | UStAE 17.1 Abs. 3a Sätze 1–2; Abs. 2 Satz 1 |

### 1.8 Reverse Charge § 13b UStG

| Regel | Fundstelle |
|---|---|
| Erfasst sind **Bauleistungen einschließlich Werklieferungen**, *„mit Ausnahme von Planungs- und Überwachungsleistungen"*. | § 13b Abs. 2 Nr. 4 Satz 1 UStG; UStAE 13b.2 Abs. 6 Satz 1 |
| **Keine** Bauleistungen: reine Materiallieferungen; Reparatur-/Wartungsarbeiten an Bauwerken, wenn das **Netto-Entgelt für den einzelnen Umsatz nicht mehr als 500 €** beträgt. Wartungsleistungen über 500 € nur, wenn Teile verändert, bearbeitet oder ausgetauscht werden. | UStAE 13b.2 Abs. 7 Nr. 1 und Nr. 15 |
| Der Empfänger schuldet die Steuer, wenn er Unternehmer ist, *„der nachhaltig entsprechende Leistungen erbringt"* — **unabhängig davon**, ob er sie für eine eigene Bauleistung verwendet. | § 13b Abs. 5 Satz 2 UStG; UStAE 13b.3 Abs. 10 |
| Gilt auch bei Bezug **für den nichtunternehmerischen Bereich** — Gegenausnahme nur für **juristische Personen des öffentlichen Rechts**. | § 13b Abs. 5 Satz 7 und Satz 11 UStG |
| Nachhaltigkeit = **mindestens 10 % des Weltumsatzes** als Bauleistungen. | UStAE 13b.3 Abs. 2 Satz 1 |
| Nachweis: Bescheinigung nach Vordruckmuster **USt 1 TG**, gültig **im Zeitpunkt der Ausführung des Umsatzes**, auf **längstens drei Jahre** befristet, **nur mit Wirkung für die Zukunft** widerrufbar. | § 13b Abs. 5 Satz 2 Halbsatz 2 UStG; UStAE 13b.3 Abs. 3 Satz 1 und Abs. 4 |
| Liegt die Bescheinigung vor, ist der Empfänger Steuerschuldner **auch dann**, wenn er sie nicht verwendet oder sich herausstellt, dass er die 10 % tatsächlich nicht erreicht. | UStAE 13b.3 Abs. 5 Satz 1 |
| Nach Widerruf schuldet der leistende Unternehmer die Steuer nur, *„wenn er hiervon Kenntnis hatte oder hätte haben können"*. | UStAE 13b.3 Abs. 5 Satz 2 |
| **Bei Anzahlungen** entsteht die Steuer mit Vereinnahmung des Teilentgelts. Liegen die 13b-Voraussetzungen **im Zeitpunkt der Vereinnahmung** nicht vor, schuldet der leistende Unternehmer die USt — **und diese Besteuerung bleibt bestehen**, auch wenn der Empfänger sie später erfüllt. | § 13b Abs. 4 Satz 2 UStG; UStAE 13b.12 Abs. 3 Sätze 3–4 |
| Rechnungspflicht: Angabe **„Steuerschuldnerschaft des Leistungsempfängers"**; der gesonderte Steuerausweis nach § 14 Abs. 4 Satz 1 Nr. 8 UStG **wird nicht angewendet**. Alle übrigen Angaben des § 14 Abs. 4 UStG bleiben — insbesondere das aufgeschlüsselte **Entgelt** (Nr. 7) und Steuernummer **oder** USt-IdNr. (Nr. 2). | § 14a Abs. 5 Sätze 1 und 2 UStG; UStAE 13b.14 Abs. 1 Sätze 1 und 3 |
| **Fehlt der Hinweis**, wird der Empfänger **nicht** von der Steuerschuldnerschaft entbunden. Weist der Leistende die Steuer dennoch gesondert aus, schuldet er sie **zusätzlich nach § 14c Abs. 1 UStG**. | UStAE 13b.14 Abs. 1 Sätze 4–5 |
| Der Vorsteuerabzug des Empfängers bleibt unberührt; eine Rechnung nach §§ 14, 14a UStG ist dafür **nicht Voraussetzung**. | § 15 Abs. 1 Satz 1 Nr. 4 UStG; UStAE 13b.15 Abs. 2 |
| **Heilung bei falscher Anwendung** nur bei übereinstimmender Annahme in Zweifelsfällen **und** wenn keine Steuerausfälle entstehen. Gilt **nicht**, wenn fraglich war, ob die Voraussetzungen **in der Person** der Beteiligten erfüllt sind. | § 13b Abs. 5 Satz 8 UStG; UStAE 13b.8 Abs. 1 Sätze 2–3 und Abs. 2 |
| Bezeichnet der Unternehmer eine Nicht-Bauleistung in der Rechnung dennoch als Bauleistung, wird der Empfänger **nicht** Steuerschuldner. | UStAE 13b.3 Abs. 13 |

### 1.9 Skonto

| Regel | Fundstelle |
|---|---|
| Die Inanspruchnahme von Skonto ist eine Änderung der Bemessungsgrundlage, *„eine Rechnungsberichtigung im Sinne von § 31 Abs. 5 UStDV ist dann nicht erforderlich"*. | UStAE 14.5 Abs. 19 Satz 7; UStAE 3.11 Abs. 5 Satz 1 |
| Es genügt der **betragslose** Hinweis: *„Bei Skontovereinbarungen genügt eine Angabe wie z. B. ‚2 % Skonto bei Zahlung bis'"*; ein betragsmäßiger Ausweis ist **nicht** erforderlich. | UStAE 14.5 Abs. 19 Sätze 11–12; § 14 Abs. 4 Satz 1 Nr. 7 UStG (*„jede im Voraus vereinbarte Minderung des Entgelts"*) |
| Belegaustauschpflicht **nur** in den Fällen des § 17 Abs. 4 UStG. | UStAE 14.5 Abs. 19 Satz 8 |
| Die Berichtigung ist im **Besteuerungszeitraum der Änderung** vorzunehmen — also im Zeitraum der skontierten Zahlung — und bereits bei der Voranmeldung zu beachten. | § 17 Abs. 1 Satz 8 UStG; UStAE 17.1 Abs. 2 Sätze 1–2 |
| Die Berichtigungspflicht besteht auch, wenn Steuer- und Vorsteuerberichtigung sich ausgleichen. | UStAE 17.1 Abs. 3 Satz 1 |
| **Nach VOB/B:** *„Nicht vereinbarte Skontoabzüge sind unzulässig."* | § 16 Abs. 5 Nr. 2 VOB/B |

### 1.10 EN 16931 / XRechnung 3.0.2

| Regel | Fundstelle |
|---|---|
| **BT-3 Invoice type code** nach UNTDID 1001; für Bau: **875** (Partial construction invoice), **876** (Partial final construction invoice), **877** (Final construction invoice). BR-DE-17 empfiehlt (SOLL) 326, 380, 384, 389, 381, 875, 876, 877. | XRechnung 3.0.2 Kap. 11.1 (BT-3); BR-DE-17; XRechnung-FAQ Bauwesen |
| Die KoSIT hält die Unterscheidung wegen §§ 14 und 16 VOB/B für verpflichtend; Baurechnungen sollen regelmäßig **kumuliert** aufgestellt werden. | XRechnung-FAQ Bauwesen |
| **BG-3 PRECEDING INVOICE REFERENCE**, Kardinalität **0..\*** — Anwendungsfall ausdrücklich: *„eine Abschlussrechnung [nimmt] auf vorangegangene Vorauszahlungsrechnungen Bezug"*. **BT-25** (Nummer) Pflicht, **BT-26** (Datum) 0..1, gefordert bei nicht eindeutiger Nummer. **BG-3 trägt keinen Betrag.** | XRechnung 3.0.2 Kap. 11.25 |
| **BT-113 Paid amount** (0..1) = Summe bereits gezahlter Beträge — **eine einzige Summe**, keine Aufschlüsselung je Abschlagsrechnung. **BT-115 Amount due for payment** ist Pflichtfeld (BR-28). **BR-CO-16:** BT-115 = BT-112 − BT-113 + BT-114. BT-115 kann negativ werden. | XRechnung 3.0.2 Kap. 11.12 (BG-22); BR-CO-16 |
| **Reverse Charge:** BT-118 = `AE`, BT-119 = 0, BT-117 = 0, BT-152 = 0. Begründung zwingend über **BT-120** (Text) oder **BT-121** (Code). Die Spezifikation nennt für BT-120 den Text *„Umkehrung der Steuerschuldnerschaft"*; BR-AE-10 lässt „Reverse charge" *„oder das Äquivalent in einer anderen Sprache"* zu. | XRechnung 3.0.2 Abschn. 12.4.4; BR-AE-9, BR-AE-10 |
| **BR-AE-2:** Es müssen BT-31 (Seller VAT identifier), BT-32 (Seller tax registration identifier) und/oder BT-63 **und** BT-48 (Buyer VAT identifier) und/oder BT-47 enthalten sein. **BR-CO-9:** ISO-3166-Alpha-2-Präfix bei BT-31/BT-48. | XRechnung 3.0.2, BR-AE-2, BR-CO-9 |
| **BR-AE-1** verlangt in der Aufschlüsselung genau **einen** AE-Eintrag, schließt weitere BG-23-Gruppen mit anderen Kategorien aber nicht aus. | XRechnung 3.0.2, BR-AE-1 |
| **Sicherheitseinbehalte:** *„In XRechnung können sie daher nicht als Nachlass auf Dokumenten- (BG-20) oder Positionsebene (BG-27/BG-DEX-03) ausgedrückt werden. … Sie können jedoch nachrichtlich – bspw. unter Verwendung des Betreffcodes ‚PMT' … als Invoice Note (BT-21/BT-22) in den Rechnungen aufgeführt werden."* | XRechnung-FAQ, Abschnitt „Elektronische Rechnungsstellung im Bauwesen" |
| **Abschlags-/Zahlungspläne:** *„Eine strukturierte Übermittlung von Abschlagsplänen ist zum aktuellen Zeitpunkt nicht vorgesehen."* Ersatz: BT-21 mit Code **AGN** (Future Plans) oder Anhang in **BG-24**. | XRechnung-FAQ, Abschnitt „Steuer- und handelsrechtliche Fragen" |
| **Skonto:** BT-20 „Payment terms", Text, 0..1. **BR-DE-18** schreibt vor: `#SKONTO#TAGE=n#PROZENT=n.nn#`, Prozent ohne Vorzeichen, Punkt, **zwei Nachkommastellen**, alles in Großbuchstaben, **kein zusätzliches Whitespace**, Zeilenende mit `#` und XML-konformem Zeilenumbruch. Bezieht sich das Skonto nur auf einen Teilbetrag (*„z. B. Material"*), ist ein viertes Segment `BASISBETRAG=n` zwingend. Der unstrukturierte Text darf **kein `#`** enthalten. | XRechnung 3.0.2 Kap. 11 (BT-20); BR-DE-18 |
| Bei positivem BT-115 muss **BT-9 (Fälligkeitsdatum) oder BT-20** vorhanden sein. | XRechnung 3.0.2 Kap. 12 |
| **Syntaxbindung** (KoSIT `xrechnung-visualization`): UBL — BT-113 → `cac:LegalMonetaryTotal/cbc:PrepaidAmount`, BT-114 → `cbc:PayableRoundingAmount`, BT-115 → `cbc:PayableAmount`, BG-3 → `cac:BillingReference/cac:InvoiceDocumentReference` (BT-25 → `cbc:ID`, BT-26 → `cbc:IssueDate`), BT-3 → `cbc:InvoiceTypeCode`. CII — BT-113 → `ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TotalPrepaidAmount`, BT-115 → `ram:DuePayableAmount`, BG-3 → `ram:InvoiceReferencedDocument` (BT-25 → `ram:IssuerAssignedID`, BT-26 → `ram:FormattedIssueDateTime/qdt:DateTimeString[@format='102']`), BT-3 → `rsm:ExchangedDocument/ram:TypeCode`. | KoSIT, `src/xsl/ubl-invoice-xr.xsl` und `src/xsl/cii-xr.xsl` |

---

## 2. Schemaentwurf (PostgreSQL)

> **Vorbemerkung zu drei Vereinheitlichungen [ANNAHME]:**
> 1. Die in den Quellen unter zwei Namen auftretende Verrechnungstabelle (`abschlag_absetzung` aus § 14 Abs. 5 Satz 2 UStG und `beleg_anrechnung` aus BG-3/BT-113) wird zu **einer** Tabelle `beleg_anrechnung` zusammengefasst. Sie trägt beide Zwecke, weil sie dieselbe Kardinalität und denselben Schlüssel hat.
> 2. Der Einbehalt wird in **`sicherheit`** (Vertragsebene, § 17 VOB/B) plus **`einbehalt_position`** (Belegebene, § 17 Abs. 6 Nr. 1 VOB/B) zerlegt statt in eine flache Tabelle `einbehalt`.
> 3. Das Vertragsregime wird als dreiwertiges Enum `('vob_b','bgb_bauvertrag','bgb_werkvertrag')` geführt (§ 650b/650c BGB verlangen die Unterscheidung Bauvertrag/Werkvertrag; § 310 Abs. 1 Satz 3 BGB die Unterscheidung VOB/B).
>
> Bedingungen, die **Zeilen anderer Tabellen** lesen, sind in Postgres nicht als `CHECK` formulierbar. Sie sind unten konsequent als `TRIGGER` gekennzeichnet.

### 2.1 Enum-Typen

```sql
-- § 14 Abs. 4 S. 1 Nr. 6 UStG i.V.m. § 31 Abs. 4 UStDV, UStAE 14.8 Abs. 4 S. 3-5:
-- der Leistungszeitpunkt der Abschlagsrechnung ist eine Variante, kein DATE.
CREATE TYPE leistungszeit_art_t AS ENUM (
  'vereinnahmung',            -- § 14 Abs. 4 S. 1 Nr. 6, 2. HS
  'voraussichtlicher_zeitpunkt', 'kalendermonat',  -- § 31 Abs. 4 UStDV
  'zeitraum',                 -- UStAE 14.8 Abs. 4 S. 4
  'noch_nicht_vereinbart');   -- UStAE 14.8 Abs. 4 S. 5

-- UStAE 14.8 Abs. 11 S. 1: Endrechnung ODER Restrechnung - gegensaetzliche Constraints.
CREATE TYPE schlussrechnung_variante_t AS ENUM ('endrechnung','restrechnung');

-- UStAE 14.8 Abs. 7 S. 2-4 und Abs. 8 Nr. 1-3: gleichwertige Darstellungsvarianten.
CREATE TYPE absetzung_darstellung_t AS ENUM (
  'einzeln_netto_steuer','summe_netto_steuer','brutto_mit_enthaltener_steuer',
  'ohne_reststeuerbetrag','zusatzangabe_ohne_absetzung','anhang','separate_zusammenstellung');

-- § 310 Abs. 1 S. 3 BGB / § 650b, § 650c BGB: steuert Fristen UND Nachtragspreisbildung.
CREATE TYPE vertragsregime_t AS ENUM ('vob_b','bgb_bauvertrag','bgb_werkvertrag');

-- § 16 Abs. 1 Nr. 3 und Abs. 3 Nr. 1 VOB/B: Fristbeginn ist der ZUGANG, nicht der Versand.
CREATE TYPE zugang_nachweis_art_t AS ENUM (
  'e_rechnung_zustellbestaetigung','einschreiben','uebergabe_quittiert','portal');

-- § 13b Abs. 2 Nr. 4 S. 1 UStG: der Status ist pro Beleg eingefroren (UStAE 13b.12 Abs. 3 S. 4).
CREATE TYPE rc_status_t       AS ENUM ('kein_rc','rc_13b_nr4');
CREATE TYPE rc_stichtag_art_t AS ENUM ('vereinnahmung','leistungsausfuehrung');

-- UStAE 13b.2 Abs. 6 S. 1 und Abs. 7 Nr. 1/Nr. 15: Ausnahmen maschinell begruendbar machen.
CREATE TYPE leistungs_kategorie_t AS ENUM (
  'ausfuehrung','planung','ueberwachung','material','wartung','reparatur');

-- § 16 Abs. 1 Nr. 1 S. 3 VOB/B: bereitgestellte Stoffe sind nur bedingt abschlagsfaehig.
CREATE TYPE position_typ_t AS ENUM ('leistung','stoff_bauteil_bereitgestellt');

-- § 17 Abs. 1 Nr. 2 VOB/B: zwei Zwecke, zwei Rueckgabezeitpunkte (Abs. 8 Nr. 1 / Nr. 2).
CREATE TYPE sicherheit_zweck_t AS ENUM ('vertragserfuellung','maengelanspruch');
CREATE TYPE sicherheit_art_t   AS ENUM ('barbehalt','buergschaft','hinterlegung_geld');
CREATE TYPE sperrkonto_typ_t   AS ENUM ('und_konto','verwahrgeld_oeffentlich'); -- § 17 Abs. 5 VOB/B
-- § 18 Abs. 1/§ 9c VOB/A NICHT belegt -> keine Prozentsatz-Defaults, nur Bemessungsbasis:
CREATE TYPE bemessungsbasis_t AS ENUM ('auftragssumme','abrechnungssumme');
-- § 17 Abs. 6 Nr. 1 S. 2 VOB/B: bei § 13b UStG bleibt die USt unberuecksichtigt.
CREATE TYPE einbehalt_basis_t AS ENUM ('brutto','netto');

-- § 2 Abs. 5/6/8 VOB/B, § 2 Abs. 3 VOB/B, § 650b BGB
CREATE TYPE nachtrag_grund_t  AS ENUM ('geaendert_2_5','zusaetzlich_2_6','ohne_auftrag_2_8','menge_2_3');
CREATE TYPE nachtrag_status_t AS ENUM ('angeordnet','angeboten','vereinbart','abgelehnt');
CREATE TYPE anordnung_form_t  AS ENUM ('schriftlich','textform','muendlich');

-- § 16 Abs. 3 Nr. 6 VOB/B: nur diese drei Gruende heben die Ausschlussfristen auf.
-- UStAE 13b.14 Abs. 1 S. 5 / § 14c Abs. 1 UStG: eigener Korrekturgrund.
CREATE TYPE korrektur_grund_t AS ENUM (
  'aufmassfehler','rechenfehler','uebertragungsfehler',
  '14c_abs1_unrichtiger_ausweis','13b_nachtraeglich','sonstige');

-- BR-DE-18 / UStAE 14.5 Abs. 19 S. 11: Skontobasis kann ein Teilbetrag sein.
CREATE TYPE skonto_basis_t AS ENUM ('gesamtbetrag','nur_material','nur_material_fremdleistung');

-- § 13 Abs. 1 Nr. 1 Buchst. a S. 4 UStG vs. § 16 Abs. 3 Nr. 1 S. 5 VOB/B:
-- die Zahlungsart ist unabhaengig von der beleg_art des Zielbelegs.
CREATE TYPE zahlungsart_t AS ENUM ('abschlag','schlusszahlung','vorauszahlung');

-- § 16 Abs. 3 Nr. 1 S. 5 VOB/B: "unbestrittenes Guthaben"
CREATE TYPE position_bestreitung_t AS ENUM ('unbestritten','bestritten');

-- § 16 Abs. 1 Nr. 4 VOB/B: Abnahme ist NIE ein Belegereignis.
CREATE TYPE abnahme_typ_t AS ENUM ('teilabnahme','gesamtabnahme','fiktiv');

-- § 16 Abs. 3 Nr. 2 und Nr. 3 VOB/B
CREATE TYPE schlusszahlungsmitteilung_art_t AS ENUM ('schlusszahlung','endgueltige_ablehnung');

-- § 17 Abs. 2 Nr. 1 UStG / UStAE 17.1 Abs. 5 S. 3
CREATE TYPE ust_berichtigung_grund_t AS ENUM (
  'uneinbringlichkeit_einbehalt','bestreiten','rueckgewaehr','skonto');
```

### 2.2 Erweiterung `vertrag` / `auftrag`

```sql
-- § 305 Abs. 2, § 310 Abs. 1 S. 3 BGB: die VOB/B gilt nur bei wirksamer Einbeziehung.
ALTER TABLE auftrag
  ADD COLUMN vertragsregime           vertragsregime_t NOT NULL DEFAULT 'bgb_werkvertrag',
  ADD COLUMN vob_b_fassung            text,                 -- z.B. '2016' (Bek. v. 07.01.2016)
  ADD COLUMN vob_b_unveraendert_einbezogen boolean,         -- § 310 Abs. 1 S. 3 BGB
  ADD COLUMN vob_b_einbezogen_am      date,
  ADD COLUMN auftraggeber_ist_verbraucher boolean NOT NULL DEFAULT false, -- § 310 Abs. 1 S. 1 BGB
  -- § 13 Abs. 1 Nr. 1 Buchst. a S. 3 UStG: Teilleistung nur bei gesonderter Entgeltvereinbarung
  ADD COLUMN teilleistungen_gesondert_vereinbart boolean NOT NULL DEFAULT false,
  -- § 14 Abs. 3 VOB/B: 12 Werktage + 6 je weitere 3 Monate Ausfuehrungsfrist
  ADD COLUMN ausfuehrungsfrist_monate numeric(6,2),
  ADD COLUMN fertigstellung_am        date,
  -- § 650c Abs. 2 S. 2 BGB: Vermutungswirkung haengt an der hinterlegten Urkalkulation
  ADD COLUMN urkalkulation_hinterlegt boolean NOT NULL DEFAULT false,
  ADD COLUMN urkalkulation_dokument_id uuid,
  -- § 14 Abs. 3, § 17 Abs. 6 Nr. 1 VOB/B rechnen in WERKTAGEN -> laenderspezifische Feiertage
  ADD COLUMN bundesland               char(2),
  ADD CONSTRAINT ck_auftrag_vobb_fassung
    CHECK (vertragsregime <> 'vob_b' OR vob_b_fassung IS NOT NULL);

-- § 14 Abs. 3 VOB/B: abgeleitete Einreichungsfrist der Schlussrechnung.
ALTER TABLE auftrag ADD COLUMN schlussrechnung_faellig_bis date; -- per Trigger aus werktage_addieren()
```

### 2.3 Erweiterung `geschaeftspartner` und `betrieb`

```sql
-- § 13b Abs. 5 S. 2, S. 7, S. 11 UStG: drei Groessen, kein Bauleistungsanteil-Feld.
ALTER TABLE geschaeftspartner
  ADD COLUMN ist_unternehmer   boolean NOT NULL DEFAULT false,
  ADD COLUMN ist_jpoer         boolean NOT NULL DEFAULT false,     -- § 13b Abs. 5 S. 11 UStG
  -- BR-CO-9: ISO-3166-Alpha-2-Praefix zwingend (BT-48)
  ADD COLUMN ust_id_nr         text CHECK (ust_id_nr ~ '^[A-Z]{2}[A-Z0-9]+$'),
  -- BR-AE-2 laesst alternativ BT-47 zu; deutsche Handwerkskunden haben oft keine USt-IdNr.
  ADD COLUMN handelsregister_nr text;
-- BEWUSST NICHT modelliert: ein Feld "bauleistungsanteil_prozent". UStAE 13b.3 Abs. 5 S. 1
-- verbietet faktisch das Nachrechnen; § 13b Abs. 5 S. 2 hat das Verwendungsmerkmal verloren
-- (UStAE 13b.3 Abs. 10).

-- § 14 Abs. 4 S. 1 Nr. 2 UStG laesst eines von beiden zu; BR-AE-2 will BT-31 und/oder BT-32.
ALTER TABLE betrieb
  ADD COLUMN steuernummer text,                                    -- BT-32
  ADD COLUMN ust_id_nr    text CHECK (ust_id_nr ~ '^[A-Z]{2}[A-Z0-9]+$'), -- BT-31, BR-CO-9
  ADD CONSTRAINT ck_betrieb_st_id CHECK (steuernummer IS NOT NULL OR ust_id_nr IS NOT NULL);

-- § 13 Abs. 1 Nr. 1 Buchst. a S. 1 UStG (Soll) vs. § 20 UStG (Ist):
-- entscheidet, ob die Einbehalts-/Uneinbringlichkeitsproblematik ueberhaupt entsteht.
ALTER TABLE mandant ADD COLUMN versteuerungsart text NOT NULL DEFAULT 'soll'
  CHECK (versteuerungsart IN ('soll','ist'));
```

### 2.4 Erweiterung `beleg`

```sql
ALTER TABLE beleg
  ---------------------------------------------------------------- Abschlagsrechnung, USt
  -- UStAE 14.8 Abs. 1 S. 1: der Anzahlungshinweis MUSS aus dem Beleg hervorgehen.
  ADD COLUMN anzahlung_hinweis        text,
  -- UStAE 14.8 Abs. 6: Vollvorausrechnung ueber 100 % ist zulaessig.
  ADD COLUMN vollvorausrechnung       boolean NOT NULL DEFAULT false,
  -- § 14 Abs. 4 S. 1 Nr. 6 UStG i.V.m. § 31 Abs. 4 UStDV, UStAE 14.8 Abs. 4 S. 3-5
  ADD COLUMN leistungszeit_art        leistungszeit_art_t,
  ADD COLUMN leistungszeit_von        date,
  ADD COLUMN leistungszeit_bis        date,
  -- § 13b Abs. 5 S. 2 UStG: Gueltigkeitstest der USt 1 TG laeuft gegen den LEISTUNGSzeitpunkt
  ADD COLUMN leistungsdatum           date,
  ADD COLUMN leistungszeitraum_von    date,
  ADD COLUMN leistungszeitraum_bis    date,
  -- UStAE 14.8 Abs. 5 S. 4-5: angefordert != vereinnahmt. Zwei Betragsebenen, nie eine.
  ADD COLUMN angefordert_netto        numeric(14,2),
  ADD COLUMN angefordert_steuer       numeric(14,2),

  ---------------------------------------------------------------- Schlussrechnung
  -- UStAE 14.8 Abs. 11 S. 1-2: Restrechnung hat gegensaetzliche Constraints zur Endrechnung.
  ADD COLUMN schlussrechnung_variante schlussrechnung_variante_t,
  -- UStAE 14.8 Abs. 7 S. 2-4, Abs. 8 Nr. 1-3: reine Darstellungswahl.
  ADD COLUMN absetzung_darstellung    absetzung_darstellung_t,
  -- UStAE 14.8 Abs. 7 S. 4: Verzicht auf Reststeuerbetrag nur bei Gesamtsteuerangabe.
  ADD COLUMN gesamtsteuer_ausgewiesen boolean NOT NULL DEFAULT false,
  -- UStAE 14.8 Abs. 11 S. 3: optionale Netto-Zusatzangabe der Restrechnung.
  ADD COLUMN restrechnung_zeigt_gesamtentgelt boolean NOT NULL DEFAULT false,

  ---------------------------------------------------------------- § 14c UStG
  -- UStAE 14.8 Abs. 10 S. 3 und UStAE 13b.14 Abs. 1 S. 5: eigenstaendige Schuld, keine
  -- Steuer auf den Umsatz -> getrennt fuehren.
  ADD COLUMN steuer_14c_abs1_betrag       numeric(14,2) NOT NULL DEFAULT 0,
  -- § 13 Abs. 1 Nr. 3 UStG: Entstehung im Zeitpunkt der AUSGABE der Rechnung.
  ADD COLUMN steuer_14c_abs1_entstanden_am date,
  -- UStAE 14.8 Abs. 10 S. 5 i.V.m. § 17 Abs. 1 UStG: Wirkung ex nunc.
  ADD COLUMN berichtigt_beleg_id       uuid REFERENCES beleg(id),
  ADD COLUMN berichtigung_wirksam_ab   date,
  ADD COLUMN korrigiert_beleg_id       uuid REFERENCES beleg(id),
  ADD COLUMN korrektur_grund           korrektur_grund_t,   -- § 16 Abs. 3 Nr. 6 VOB/B

  ---------------------------------------------------------------- VOB/B-Fristen
  -- § 310 Abs. 1 S. 3 BGB: Regime am Beleg einfrieren, sonst rechnet die Software spaeter
  -- mit anderen Fristen als zum Belegdatum galten.
  ADD COLUMN vertragsregime           vertragsregime_t,
  -- § 16 Abs. 1 Nr. 3 / Abs. 3 Nr. 1 VOB/B: Fristbeginn ist der Zugang beim Auftraggeber.
  ADD COLUMN zugang_beim_empfaenger_am date,
  ADD COLUMN zugang_nachweis_art      zugang_nachweis_art_t,
  -- § 16 Abs. 3 Nr. 1 S. 1-2 VOB/B
  ADD COLUMN pruef_frist_tage         smallint CHECK (pruef_frist_tage IN (30,60)),
  ADD COLUMN frist_verlaengerung_ausdruecklich_vereinbart boolean NOT NULL DEFAULT false,
  -- § 16 Abs. 1 Nr. 3 VOB/B (21 Tage) vs. § 16 Abs. 5 Nr. 3 VOB/B (30 Tage Verzug):
  -- ZWEI Datumsfelder, weil beides bei Abschlagsrechnungen auseinanderfaellt.
  ADD COLUMN faellig_am               date,
  ADD COLUMN verzug_ab                date,
  -- § 16 Abs. 3 Nr. 1 S. 5 VOB/B: unbestrittenes Guthaben ist sofort zu zahlen.
  ADD COLUMN betrag_unbestritten      numeric(14,2),
  -- § 16 Abs. 1 Nr. 1 VOB/B: leistungsstandsbasiert, nicht zahlungsplanbasiert.
  ADD COLUMN abschlag_nr              integer,
  ADD COLUMN leistungsstand_stichtag  date,
  ADD COLUMN aufstellung_id           uuid REFERENCES leistungsnachweis(id),
  ADD COLUMN antrag_gestellt_am       date,
  -- § 14 Abs. 1 S. 4 VOB/B: Nachtraege auf Verlangen getrennt abrechnen.
  ADD COLUMN getrennte_abrechnung     boolean NOT NULL DEFAULT false,

  ---------------------------------------------------------------- § 13b UStG
  ADD COLUMN rc_status                rc_status_t NOT NULL DEFAULT 'kein_rc',
  -- § 13b Abs. 4 S. 2 UStG vs. § 13 Abs. 1 Nr. 1 Buchst. a S. 1 UStG
  ADD COLUMN rc_stichtag              date,
  ADD COLUMN rc_stichtag_art          rc_stichtag_art_t,
  -- UStAE 13b.3 Abs. 3 S. 1 / Abs. 5 S. 1: Snapshot, weil Belege unveraenderlich sind.
  ADD COLUMN rc_bescheinigung_id      uuid REFERENCES freistellungsbescheinigung_13b(id),
  ADD COLUMN rc_bescheinigung_nr      text,
  ADD COLUMN rc_bescheinigung_gueltig_bis date,
  -- UStAE 13b.14 Abs. 1 S. 5: Pruefung muss VOR dem Festschreiben protokolliert sein.
  ADD COLUMN rc_geprueft_am           timestamptz,
  ADD COLUMN rc_geprueft_durch        uuid,
  -- § 14a Abs. 5 S. 1 UStG: Gesetzeswortlaut, nicht anwenderseitig editierbar.
  ADD COLUMN rc_hinweis_text          text,
  -- § 13b Abs. 5 S. 8 UStG / UStAE 13b.8 Abs. 2: NUR Achse A ist heilbar.
  ADD COLUMN rc_zweifel_leistungsart  boolean NOT NULL DEFAULT false,
  ADD COLUMN rc_einvernehmen_dokumentiert boolean NOT NULL DEFAULT false,
  ADD COLUMN rc_einvernehmen_dokument_id uuid,
  -- § 13b Abs. 5 S. 11 UStG: nur der nichtunternehmerische Bezug der jPoeR ist ausgenommen.
  ADD COLUMN bezug_nichtunternehmerisch boolean NOT NULL DEFAULT false,
  -- XRechnung 12.4.4 / BR-AE-10: Text und Code getrennt, damit die Pruefung nicht am
  -- Textvergleich haengt (§ 14a Abs. 5 S. 1 UStG verlangt einen anderen Wortlaut als
  -- die Detailbeschreibung zu BT-120).
  ADD COLUMN bt120_exemption_text     text,
  ADD COLUMN bt121_exemption_code     text,

  ---------------------------------------------------------------- EN 16931 Summen
  -- BT-113 (0..1) ist EINE Summe; die Aufschluesselung lebt in beleg_anrechnung.
  ADD COLUMN bereits_gezahlt_brutto   numeric(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN rundungsbetrag           numeric(14,2) NOT NULL DEFAULT 0,   -- BT-114
  -- BR-CO-16 als DB-Constraint, damit BT-115 nicht driften kann. Kein CHECK >= 0:
  -- die Spezifikation laesst BT-115 ausdruecklich negativ werden.
  ADD COLUMN restbetrag_brutto        numeric(14,2)
      GENERATED ALWAYS AS (brutto_betrag - bereits_gezahlt_brutto + rundungsbetrag) STORED,
  -- BT-3, BR-DE-17: beim Festschreiben einfrieren, nicht zur Laufzeit ableiten.
  ADD COLUMN untdid_1001_code         text,

  ---------------------------------------------------------------- Skonto
  -- § 16 Abs. 5 Nr. 2 VOB/B: nicht vereinbarte Skontoabzuege sind unzulaessig
  -- -> kein Mandanten-Default, explizit pro Beleg.
  ADD COLUMN skonto_vereinbart        boolean NOT NULL DEFAULT false,
  ADD COLUMN skonto_basis             skonto_basis_t,
  -- UStAE 14.5 Abs. 19 S. 11-12: betragsloser Hinweis genuegt.
  ADD COLUMN skonto_hinweistext       text,
  -- BT-20: der unstrukturierte Text darf kein '#' enthalten (BR-DE-18 Segmentierung).
  ADD COLUMN zahlungsbedingungen_text text,

  ---------------------------------------------------------------- § 17 Abs. 6 Nr. 1 S. 2 VOB/B
  ADD COLUMN einbehalt_bemessung numeric(14,2)
      GENERATED ALWAYS AS (CASE WHEN rc_status = 'rc_13b_nr4'
                                THEN netto_betrag ELSE brutto_betrag END) STORED;
```

#### CHECK-Bedingungen auf `beleg`

```sql
-- UStAE 14.8 Abs. 1 S. 1: Traeger des Voraus-/Anzahlungsausweises ist Pflicht.
ALTER TABLE beleg ADD CONSTRAINT ck_anzahlung_hinweis
  CHECK (beleg_art <> 'abschlagsrechnung' OR anzahlung_hinweis IS NOT NULL);

-- § 14 Abs. 4 S. 1 Nr. 6 UStG i.V.m. § 31 Abs. 4 UStDV; die Angabe darf entfallen,
-- wenn der Vereinnahmungszeitpunkt mit dem Ausstellungsdatum uebereinstimmt
-- -> bedingter, kein unbedingter NOT-NULL-Zwang.
ALTER TABLE beleg ADD CONSTRAINT ck_leistungszeit_abschlag CHECK (
  beleg_art <> 'abschlagsrechnung' OR (
       leistungszeit_art IS NOT NULL
   AND (leistungszeit_art = 'noch_nicht_vereinbart'
        OR leistungszeit_von IS NOT NULL
        OR leistungszeit_von = ausstellungsdatum)
   AND (leistungszeit_art <> 'zeitraum' OR leistungszeit_bis IS NOT NULL)));

-- UStAE 14.8 Abs. 11 S. 1: die Belegart 'schlussrechnung' zerfaellt in zwei Varianten.
ALTER TABLE beleg ADD CONSTRAINT ck_sr_variante
  CHECK ((beleg_art = 'schlussrechnung') = (schlussrechnung_variante IS NOT NULL));

ALTER TABLE beleg ADD CONSTRAINT ck_absetzung_darstellung
  CHECK (beleg_art <> 'schlussrechnung' OR absetzung_darstellung IS NOT NULL);

-- UStAE 14.8 Abs. 7 S. 4: Reststeuerverzicht nur bei angegebener Gesamtsteuer.
ALTER TABLE beleg ADD CONSTRAINT ck_ohne_reststeuer
  CHECK (absetzung_darstellung <> 'ohne_reststeuerbetrag' OR gesamtsteuer_ausgewiesen);

-- BMF v. 15.10.2025 Rn. 35: blosser Verweis auf eine unstrukturierte Anlage genuegt nicht.
-- Sperre gilt, bis Rn. 47/48 des BMF-Schreibens v. 15.10.2024 geprueft sind (siehe Abschnitt 5).
ALTER TABLE beleg ADD CONSTRAINT ck_absetzung_erechnung
  CHECK (rechnungsformat NOT IN ('xrechnung','zugferd')
         OR absetzung_darstellung NOT IN ('anhang','separate_zusammenstellung'));

-- § 16 Abs. 3 Nr. 1 S. 2 VOB/B: 60 Tage nur bei ausdruecklicher Vereinbarung (kumulativ).
ALTER TABLE beleg ADD CONSTRAINT ck_prueffrist_60
  CHECK (pruef_frist_tage IS DISTINCT FROM 60 OR frist_verlaengerung_ausdruecklich_vereinbart);

-- § 16 Abs. 1 Nr. 3 / Abs. 3 Nr. 1 VOB/B: ohne Zugangsdatum ist keine Faelligkeit berechenbar.
ALTER TABLE beleg ADD CONSTRAINT ck_zugang_vobb
  CHECK (vertragsregime <> 'vob_b'
         OR beleg_art NOT IN ('abschlagsrechnung','schlussrechnung','teilschlussrechnung')
         OR status <> 'festgeschrieben'
         OR zugang_beim_empfaenger_am IS NOT NULL);

-- § 14a Abs. 5 S. 2 UStG: § 14 Abs. 4 S. 1 Nr. 8 wird NICHT angewendet.
-- Nr. 7 (Entgelt) bleibt dagegen Pflicht -> netto_betrag bleibt NOT NULL.
ALTER TABLE beleg ADD CONSTRAINT ck_rc_kein_steuerausweis
  CHECK (rc_status <> 'rc_13b_nr4' OR (steuer_betrag = 0 AND steuersatz IS NULL));

-- § 14a Abs. 5 S. 1 UStG: Gesetzeswortlaut, kontrollierter Wert statt Freitext.
ALTER TABLE beleg ADD CONSTRAINT ck_rc_hinweis
  CHECK (rc_status <> 'rc_13b_nr4'
         OR rc_hinweis_text = 'Steuerschuldnerschaft des Leistungsempfängers');

-- UStAE 13b.8 Abs. 2 i.V.m. 13b.3 Abs. 3 S. 1: Zweifel an der PERSON sind nicht heilbar,
-- also ist die USt 1 TG die einzige zulaessige Grundlage.
ALTER TABLE beleg ADD CONSTRAINT ck_rc_bescheinigung
  CHECK (rc_status <> 'rc_13b_nr4' OR rc_bescheinigung_id IS NOT NULL);

-- § 13b Abs. 4 S. 2 UStG vs. § 13 Abs. 1 Nr. 1 Buchst. a S. 1 UStG
ALTER TABLE beleg ADD CONSTRAINT ck_rc_stichtag CHECK (
  rc_status <> 'rc_13b_nr4' OR (
    rc_stichtag IS NOT NULL AND rc_stichtag_art IS NOT NULL
    AND (beleg_art <> 'abschlagsrechnung' OR rc_stichtag_art = 'vereinnahmung')
    AND (beleg_art NOT IN ('schlussrechnung','teilschlussrechnung','teilrechnung')
         OR rc_stichtag_art = 'leistungsausfuehrung')));

-- XRechnung Abschn. 12.4.4 / BR-AE-9: Begruendung zwingend, Text ODER Code.
ALTER TABLE beleg ADD CONSTRAINT ck_rc_exemption
  CHECK (rc_status <> 'rc_13b_nr4'
         OR bt120_exemption_text IS NOT NULL OR bt121_exemption_code IS NOT NULL);

-- § 16 Abs. 5 Nr. 2 VOB/B: Skontoprozente nur bei ausdruecklicher Vereinbarung.
ALTER TABLE beleg ADD CONSTRAINT ck_skonto_vereinbart
  CHECK (skonto_vereinbart OR (skonto_basis IS NULL AND skonto_hinweistext IS NULL));

-- BT-20: der unstrukturierte Text darf kein '#' enthalten.
ALTER TABLE beleg ADD CONSTRAINT ck_zahlungsbed_ohne_raute
  CHECK (zahlungsbedingungen_text IS NULL OR position('#' in zahlungsbedingungen_text) = 0);

-- UStAE 14.8 Abs. 6: eine Vollvorausrechnung schliesst weitere Abschlaege desselben
-- Auftrags aus. KEIN CHECK 'abschlag_netto < auftragssumme' - 100 % sind zulaessig.
CREATE UNIQUE INDEX ux_beleg_vollvorausrechnung
  ON beleg(auftrag_id) WHERE vollvorausrechnung;

-- § 13 Abs. 1 Nr. 1 Buchst. a S. 3 UStG: Teilleistung setzt gesonderte Entgeltvereinbarung
-- voraus - als TRIGGER, weil auftrag.teilleistungen_gesondert_vereinbart gelesen wird.
```

### 2.5 Erweiterung `beleg_position`

```sql
ALTER TABLE beleg_position
  -- § 14 Abs. 1 S. 2 VOB/B: Reihenfolge der Posten einhalten, Vertragsbezeichnungen verwenden.
  ADD COLUMN ordnungszahl        text,               -- OZ aus dem LV
  ADD COLUMN sort_index          integer NOT NULL DEFAULT 0,
  ADD COLUMN vertrag_position_id uuid,
  -- UStAE 14.8 Abs. 4 S. 2: die Leistung muss schon bei Anzahlung "genau bestimmt" sein.
  ADD COLUMN quell_position_id   uuid,
  -- § 16 Abs. 1 Nr. 1 S. 1-2 VOB/B: Wert der NACHGEWIESENEN Leistung, kein Pauschalbetrag.
  ADD COLUMN menge_nachgewiesen  numeric(14,3),
  ADD COLUMN einheitspreis       numeric(14,4),
  ADD COLUMN wert_nachgewiesen   numeric(14,2),
  ADD COLUMN aufmass_position_id uuid,               -- § 14 Abs. 2 VOB/B (Nachweiskette)
  -- § 16 Abs. 1 Nr. 1 S. 3 VOB/B: bereitgestellte Stoffe nur bei Eigentum oder Sicherheit.
  ADD COLUMN position_typ        position_typ_t NOT NULL DEFAULT 'leistung',
  ADD COLUMN eigentumsuebergang_am date,
  ADD COLUMN sicherheit_id       uuid REFERENCES sicherheit(id),
  -- § 13b Abs. 2 Nr. 4 S. 1 UStG / UStAE 13b.2 Abs. 6 S. 1, Abs. 7 Nr. 1 und 15:
  -- das Merkmal ist leistungsbezogen, nicht belegbezogen.
  ADD COLUMN ist_bauleistung_13b boolean NOT NULL DEFAULT false,
  ADD COLUMN leistungs_kategorie leistungs_kategorie_t,
  -- UStAE 13b.2 Abs. 7 Nr. 15: die 500-EUR-Grenze bezieht sich auf "den einzelnen Umsatz",
  -- braucht also eine Klammer oberhalb der Belegzeile.
  ADD COLUMN leistungs_gruppe_id uuid,
  -- § 14 Abs. 1 S. 4 VOB/B: Nachtraege besonders kenntlich machen.
  ADD COLUMN ist_nachtrag        boolean NOT NULL DEFAULT false,
  ADD COLUMN nachtrag_id         uuid REFERENCES nachtrag(id),
  -- § 650c Abs. 3 S. 1 BGB: 80-%-Ansatz ist vorlaeufig und rueckforderbar (S. 3).
  ADD COLUMN vorlaeufig_nach_650c_3 boolean NOT NULL DEFAULT false,
  -- § 16 Abs. 3 Nr. 1 S. 5 VOB/B: unbestrittenes Guthaben ist sofort zu zahlen.
  ADD COLUMN bestreitung         position_bestreitung_t NOT NULL DEFAULT 'unbestritten';

-- § 16 Abs. 1 Nr. 1 S. 3 VOB/B
ALTER TABLE beleg_position ADD CONSTRAINT ck_stoff_abschlagsfaehig
  CHECK (position_typ <> 'stoff_bauteil_bereitgestellt'
         OR eigentumsuebergang_am IS NOT NULL OR sicherheit_id IS NOT NULL);

-- § 14a Abs. 5 S. 2 UStG auch je Zeile.
ALTER TABLE beleg_position ADD CONSTRAINT ck_pos_rc_kein_steuerausweis
  CHECK (NOT ist_reverse_charge OR (steuersatz = 0 AND steuerbetrag = 0));

-- UStAE 14.8 Abs. 4 S. 2: keine generische Leistungsbeschreibung ("Abschlag 1").
ALTER TABLE beleg_position ALTER COLUMN bezeichnung SET NOT NULL;
```

**Trigger auf `beleg_position` (Fremdzeilen-Bedingungen):**

| Trigger | Regel | Fundstelle |
|---|---|---|
| `trg_pos_summe_gleich_entgelt` | `SUM(lohn+material+fremdleistung) = beleg.entgelt_netto` | UStAE 14.8 Abs. 4 S. 2 (genau bestimmte Leistung) |
| `trg_pos_bezeichnung_vertragstreu` | Abweichung von `vertrag_position.bezeichnung` nur bei `ist_nachtrag = true` | § 14 Abs. 1 S. 2 VOB/B |
| `trg_pos_13b_homogen` | Beleg mit `rc_status='rc_13b_nr4'` darf keine Position mit `ist_bauleistung_13b = false` enthalten | § 13b Abs. 2 Nr. 4 S. 1 UStG; UStAE 13b.2 Abs. 6 S. 1 |
| `trg_pos_500_euro` | `SUM(netto)` je `leistungs_gruppe_id` > 500 prüfen, wenn `leistungs_kategorie IN ('wartung','reparatur')` | UStAE 13b.2 Abs. 7 Nr. 15 |
| `trg_pos_nachtrag_verguetungsfaehig` | Position mit `nachtrag.grund='ohne_auftrag_2_8'` nur einfügbar, wenn `verguetungsfaehig` | § 2 Abs. 8 Nr. 1 und Nr. 2 VOB/B |

### 2.6 Neue Tabelle `zahlung` — die Steuerbemessungsebene

```sql
-- § 13 Abs. 1 Nr. 1 Buchst. a S. 4 UStG; UStAE 13.5 Abs. 1 S. 1; UStAE 13.6 Abs. 1 S. 3.
-- Der Steuerentstehungszeitpunkt darf NICHT aus beleg.belegdatum abgeleitet werden.
CREATE TABLE zahlung (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mandant_id             uuid NOT NULL,
  beleg_id               uuid NOT NULL REFERENCES beleg(id),
  -- UStAE 13.6 Abs. 1 S. 3: verbindlich das GUTSCHRIFTsdatum des Bankkontos.
  -- Nicht Wertstellung, nicht Ueberweisungsauftrag, nicht CRM-Buchungsdatum.
  vereinnahmt_am         date NOT NULL,
  betrag_brutto          numeric(14,2) NOT NULL,
  entgelt_netto          numeric(14,2) NOT NULL,
  steuersatz             numeric(5,2)  NOT NULL,
  steuerbetrag           numeric(14,2) NOT NULL,
  -- § 13b Abs. 4 S. 2 UStG / UStAE 13b.12 Abs. 3 S. 3-4: Status je Vereinnahmung.
  rc_status              rc_status_t NOT NULL DEFAULT 'kein_rc',
  -- § 16 Abs. 3 Nr. 1 S. 5 VOB/B: eine Teilzahlung auf eine Schlussrechnung kann eine
  -- Abschlagszahlung sein - unabhaengig von der beleg_art des Zielbelegs.
  zahlungsart            zahlungsart_t NOT NULL,
  -- UStAE 14.5 Abs. 19 S. 7 / § 17 Abs. 1 S. 8 UStG: Skonto lebt hier, nie am Beleg.
  skonto_betrag_brutto   numeric(14,2) NOT NULL DEFAULT 0,
  entgeltminderung_netto numeric(14,2) NOT NULL DEFAULT 0,
  ust_korrekturbetrag    numeric(14,2) NOT NULL DEFAULT 0,
  -- § 16 Abs. 5 Nr. 2 VOB/B: einseitige unberechtigte Kuerzung ist KEINE Entgeltminderung.
  skonto_abzug_berechtigt boolean NOT NULL DEFAULT true,
  -- § 17 Abs. 1 S. 8 UStG: Periode der ZAHLUNG, nicht der Rechnung.
  ust_berichtigung_periode date GENERATED ALWAYS AS (date_trunc('month', vereinnahmt_am)::date) STORED,
  CHECK (steuerbetrag = 0 OR rc_status = 'kein_rc')   -- § 14a Abs. 5 S. 2 UStG
);
CREATE INDEX ix_zahlung_vor ON zahlung (mandant_id, vereinnahmt_am);
-- Kardinalitaet beleg 1:0..n zahlung, NICHT 1:1 (UStAE 14.8 Abs. 5 S. 3-4).
-- KEIN CHECK, der zahlung.periode = beleg.periode erzwingt (§ 17 Abs. 1 S. 8 UStG).
-- Der Unveraenderlichkeits-Trigger fuer festgeschriebene Belege darf NICHT auf 'zahlung'
-- ausgeweitet werden - sonst ist Skonto nicht buchbar (UStAE 14.5 Abs. 19 S. 7).
```

**Harte Negativregeln zu `zahlung`** (UStAE 14.8 Abs. 5 Sätze 4–5, Abs. 2 Satz 1):

* Kein Trigger `ON zahlung INSERT WHERE betrag < angefordert THEN create storno`. Unterzahlung erzeugt **keinen** Korrektur-, Storno- oder Berichtigungsbeleg — das verbrauchte grundlos eine Belegnummer.
* Kein automatischer 14c-Vermerk bei Nichtzahlung.
* `beleg.status` (`'entwurf'`/`'festgeschrieben'`) und der Zahlungsstand sind **unabhängig**. Der Zahlungsstand ist eine View über `SUM(zahlung.betrag_brutto)`, keine Spalte auf `beleg`.

```sql
CREATE VIEW v_beleg_zahlungsstand AS
SELECT b.id AS beleg_id,
       b.brutto_betrag,
       COALESCE(SUM(z.betrag_brutto),0) AS gezahlt_brutto,
       COALESCE((SELECT SUM(ep.betrag) FROM einbehalt_position ep
                 WHERE ep.beleg_id = b.id),0) AS einbehalten,
       -- § 10 Abs. 1 S. 2 UStG: der Einbehalt mindert die Forderung nicht, nur den Zahlbetrag.
       b.brutto_betrag - COALESCE((SELECT SUM(ep.betrag) FROM einbehalt_position ep
                                   WHERE ep.beleg_id = b.id),0) AS zahlbetrag
FROM beleg b LEFT JOIN zahlung z ON z.beleg_id = b.id
GROUP BY b.id;
```

### 2.7 Neue Tabelle `beleg_anrechnung` — Absetzung (§ 14 Abs. 5 S. 2 UStG) und BG-3

```sql
-- § 14 Abs. 5 S. 2 UStG; UStAE 14.8 Abs. 7 S. 1; UStAE 13b.12 Abs. 3 S. 4;
-- XRechnung 3.0.2 Kap. 11.25 (BG-3) und Kap. 11.12 (BT-113).
CREATE TABLE beleg_anrechnung (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schlussrechnung_id    uuid NOT NULL REFERENCES beleg(id),
  abschlagsrechnung_id  uuid NOT NULL REFERENCES beleg(id),
  -- § 14 Abs. 5 S. 2 UStG knuepft an die VEREINNAHMTEN Teilentgelte an, nicht an die
  -- blosse Existenz einer Rechnung -> FK auf zahlung, nicht nur auf beleg.
  zahlung_id            uuid NOT NULL REFERENCES zahlung(id),
  vereinnahmt_am        date NOT NULL,
  -- Pro Steuersatz zu fuehren: § 14 Abs. 5 S. 2 verlangt "die auf sie entfallenden
  -- Steuerbetraege" - eine Bruttosumme genuegt nicht.
  entgelt_netto         numeric(14,2) NOT NULL,
  steuersatz            numeric(5,2)  NOT NULL,
  steuerbetrag          numeric(14,2) NOT NULL,
  angerechneter_brutto  numeric(14,2) NOT NULL,
  -- UStAE 13b.12 Abs. 3 S. 4: der damalige Status bleibt bestehen -> KOPIEREN, nie neu rechnen.
  rc_status             rc_status_t NOT NULL,
  -- BG-3/BT-25/BT-26: denormalisierte Kopie, weil die festgeschriebene Rechnung den
  -- uebermittelten Wert unveraenderlich behalten muss.
  vorbeleg_nummer       text NOT NULL,   -- BT-25 (Pflicht, Anz. 1)
  vorbeleg_datum        date NOT NULL,   -- BT-26 (0..1; immer mitschreiben)
  UNIQUE (schlussrechnung_id, abschlagsrechnung_id, zahlung_id),
  -- § 14a Abs. 5 S. 2 UStG i.V.m. UStAE 13b.12 Abs. 3 S. 4
  CHECK (rc_status <> 'rc_13b_nr4' OR (steuerbetrag = 0 AND steuersatz = 0))
);
```

**Trigger beim Festschreiben (blockierend, BEFORE):**

| Prüfung | Regel | Fundstelle |
|---|---|---|
| Bei `schlussrechnung_variante='endrechnung'`: `SUM(beleg_anrechnung.steuerbetrag)` **je Steuersatz** muss **gleich** `SUM(zahlung.steuerbetrag)` aller vereinnahmten Abschlagszahlungen desselben Auftrags mit gesondertem Steuerausweis sein. Gleichheit prüfen, nicht `>= 0` — **Teil**absetzung ist ebenso schädlich wie Nullabsetzung. | UStAE 14.8 Abs. 10 Sätze 1–3 |
| Auswahlbasis der Absetzung sind die **vereinnahmten Zahlungen**, **nicht** `WHERE beleg.storniert = false` — ein Storno der Abschlagsrechnung darf sie nicht aus der Basis filtern. | UStAE 14.8 Abs. 9 Satz 1 |
| Bei `schlussrechnung_variante='restrechnung'`: `NOT EXISTS(beleg_anrechnung)` und der Gleichheitstrigger **darf nicht feuern**. | UStAE 14.8 Abs. 11 Satz 2 |
| `SUM(beleg_anrechnung.angerechneter_brutto) = beleg.bereits_gezahlt_brutto` | BR-CO-16 / BT-113 |
| Eine Schlussrechnung (877) darf nur festgeschrieben werden, wenn **alle** vereinnahmten Abschlagszahlungen desselben Auftrags erfasst sind. | § 14 Abs. 5 Satz 2 UStG; XRechnung Kap. 11.25 |

### 2.8 Neue Tabelle `beleg_steueraufschluesselung` — BG-23

```sql
-- BR-AE-1 verlangt genau EINEN AE-Eintrag, schliesst weitere BG-23-Gruppen nicht aus.
-- UStAE 13b.12 Abs. 3 S. 4 erzwingt gemischte Kategorien auf EINER Schlussrechnung.
-- Ein einziges Steuersatzfeld je Beleg ist an dieser Stelle nicht reparabel.
CREATE TABLE beleg_steueraufschluesselung (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id           uuid NOT NULL REFERENCES beleg(id),
  ust_kategorie      char(2) NOT NULL,        -- BT-118
  bemessungsgrundlage numeric(14,2) NOT NULL, -- Bemessungsgrundlage je BG-23-Gruppe
  steuersatz         numeric(5,2)  NOT NULL,  -- BT-119
  steuerbetrag       numeric(14,2) NOT NULL,  -- BT-117
  exemption_text     text,                    -- BT-120
  exemption_code     text,                    -- BT-121
  UNIQUE (beleg_id, ust_kategorie, steuersatz),
  -- BR-AE-9: bei AE muss BT-117 gleich 0 sein; XRechnung 12.4.4: BT-119 = 0.
  CHECK (ust_kategorie <> 'AE' OR (steuersatz = 0 AND steuerbetrag = 0)),
  -- XRechnung 12.4.4: Begruendung ist bei AE immer erforderlich.
  CHECK (ust_kategorie <> 'AE' OR exemption_text IS NOT NULL OR exemption_code IS NOT NULL)
);
-- BR-AE-1: hoechstens eine AE-Gruppe je Beleg.
CREATE UNIQUE INDEX ux_bg23_ae ON beleg_steueraufschluesselung(beleg_id)
  WHERE ust_kategorie = 'AE';
```

### 2.9 Sicherheiten und Einbehalte

```sql
-- § 17 Abs. 1 Nr. 2, Abs. 5, Abs. 6 Nr. 1-3, Abs. 8 Nr. 1-2 VOB/B.
CREATE TABLE sicherheit (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id           uuid NOT NULL REFERENCES auftrag(id),
  zweck                sicherheit_zweck_t NOT NULL,       -- § 17 Abs. 1 Nr. 2 VOB/B
  art                  sicherheit_art_t   NOT NULL,
  -- § 17 Abs. 6 Nr. 1 S. 1 VOB/B: ZWEI verschiedene Groessen, niemals eine Spalte.
  einbehalt_rate_prozent numeric(5,2) CHECK (einbehalt_rate_prozent <= 10.00), -- max. Kuerzung je Zahlung
  sicherheitssumme_soll  numeric(12,2) NOT NULL,          -- vertraglicher Zielbetrag, ohne ges. Obergrenze
  einbehalten_ist        numeric(12,2) NOT NULL DEFAULT 0,
  -- § 18 VOB/A nicht primaerbelegt -> Bemessungsbasis als Feld, keine Prozent-Defaults.
  bemessungsbasis        bemessungsbasis_t NOT NULL,
  -- § 17 Abs. 6 Nr. 1 S. 2 VOB/B: bei § 13b UStG bleibt die USt unberuecksichtigt.
  einbehalt_basis        einbehalt_basis_t NOT NULL,
  -- § 17 Abs. 5 VOB/B: Und-Konto, Zinsen stehen dem Auftragnehmer zu.
  sperrkonto_iban        text,
  sperrkonto_institut    text,
  sperrkonto_typ         sperrkonto_typ_t,
  -- § 17 Abs. 8 Nr. 1 / Nr. 2 VOB/B: unterschiedliche Rueckgabezeitpunkte je Zweck.
  freigabe_soll          date,
  freigabe_vereinbart    date,     -- Abs. 8 Nr. 2: "sofern kein anderer ... vereinbart"
  freigegeben_am         date,
  verwertet_betrag       numeric(12,2) NOT NULL DEFAULT 0,
  CHECK (einbehalten_ist <= sicherheitssumme_soll)        -- § 17 Abs. 6 Nr. 1 S. 1 VOB/B
);
-- § 17 Abs. 8 Nr. 1 VOB/B: die Maengelsicherheit loest die Vertragserfuellungssicherheit ab
-- -> nie zwei aktive Zeilen desselben Zwecks.
CREATE UNIQUE INDEX ux_sicherheit_aktiv ON sicherheit(auftrag_id, zweck)
  WHERE freigegeben_am IS NULL;

-- § 17 Abs. 6 Nr. 1 S. 1 VOB/B: haelt fest, welcher Beleg wie viel beigetragen hat -
-- ohne die Belegsummen zu veraendern (§ 10 Abs. 1 S. 2 UStG).
CREATE TABLE einbehalt_position (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id      uuid NOT NULL REFERENCES beleg(id),
  sicherheit_id uuid NOT NULL REFERENCES sicherheit(id),
  betrag        numeric(12,2) NOT NULL CHECK (betrag >= 0),
  -- § 17 Abs. 8 Nr. 2 VOB/B: eigene Faelligkeit, unabhaengig von beleg.faellig_am.
  faellig_ab    date,
  UNIQUE (beleg_id, sicherheit_id)
);

-- § 17 Abs. 6 Nr. 1 S. 3 und Nr. 3 VOB/B: Mitteilung -> 18 Werktage -> Nachfrist -> Verwirkung.
CREATE TABLE einbehalt_frist (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sicherheit_id         uuid NOT NULL REFERENCES sicherheit(id),
  einbehalt_position_id uuid REFERENCES einbehalt_position(id),
  mitteilung_am         date NOT NULL,
  -- WERKTAGE, nicht Kalendertage: einzahlung_faellig_am = werktage_addieren(mitteilung_am,18,bl)
  einzahlung_faellig_am date NOT NULL,
  eingezahlt_am         date,
  nachfrist_gesetzt_am  date,
  nachfrist_ende        date,
  -- § 17 Abs. 6 Nr. 3 S. 2 VOB/B: sofortige Auszahlung, keine Sicherheit mehr zu leisten.
  verwirkt              boolean NOT NULL DEFAULT false
);

CREATE TABLE sicherheit_ereignis (          -- revisionssichere Historie
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sicherheit_id uuid NOT NULL REFERENCES sicherheit(id),
  ereignis      text NOT NULL, ereignis_am timestamptz NOT NULL DEFAULT now(),
  betrag        numeric(12,2), bemerkung text
);
```

**Berechnungsregeln (Funktionen, nicht Constraints):**

```sql
-- § 17 Abs. 6 Nr. 1 S. 1 VOB/B: Kappung bei Erreichen der Sicherheitssumme.
-- § 17 Abs. 6 Nr. 1 S. 2 VOB/B: Basis wechselt mit der Steuerschuldnerschaft.
-- einbehalt = LEAST(rate/100 * beleg.einbehalt_bemessung,
--                   sicherheit.sicherheitssumme_soll - sicherheit.einbehalten_ist)
```

**Trigger:** `sicherheit.einbehalt_basis` muss `'netto'` sein, sobald der zugehörige Beleg `rc_status='rc_13b_nr4'` trägt (§ 17 Abs. 6 Nr. 1 Satz 2 VOB/B). Ein Brutto-Einbehalt wäre rechnerisch falsch, weil keine USt ausgewiesen ist.

> **[ANNAHME]** Der Umkehrschluss „im Regelfall Brutto" ist eine Ableitung aus dem Normzweck von § 17 Abs. 6 Nr. 1 Satz 2 VOB/B, nicht wörtlich normiert. `einbehalt_basis` bleibt deshalb pro Sicherheit überschreibbar.

### 2.10 Umsatzsteuer-Berichtigung (§ 17 UStG)

```sql
-- § 17 Abs. 2 Nr. 1 UStG; UStAE 17.1 Abs. 5 S. 3, Abs. 3a S. 1-2, Abs. 2 S. 1.
CREATE TABLE ust_berichtigung (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id           uuid NOT NULL REFERENCES beleg(id),
  sicherheit_id      uuid REFERENCES sicherheit(id),
  zahlung_id         uuid REFERENCES zahlung(id),
  grund              ust_berichtigung_grund_t NOT NULL,
  netto_betrag       numeric(14,2) NOT NULL,
  ust_betrag         numeric(14,2) NOT NULL,
  -- UStAE 17.1 Abs. 2 S. 1: Zeitraum, in dem die AENDERUNG eingetreten ist.
  voranmeldungszeitraum date NOT NULL,
  -- UStAE 17.1 Abs. 5 S. 3: ohne Nachweis der Buergschaftsunmoeglichkeit keine Berichtigung.
  nachweis_buergschaft_unmoeglich boolean NOT NULL DEFAULT false,
  nachweis_dokument_id uuid,
  erfasst_am         timestamptz NOT NULL DEFAULT now(),
  rueckgaengig_zu_id uuid REFERENCES ust_berichtigung(id),
  CHECK (grund <> 'uneinbringlichkeit_einbehalt' OR nachweis_buergschaft_unmoeglich)
);
-- UStAE 17.1 Abs. 5 S. 3 nennt "ueber zwei bis fuenf Jahre": Anlage erst zulaessig, wenn
-- die Faelligkeit ueber zwei Jahre zurueckliegt -> TRIGGER (liest beleg.faellig_am).
-- UStAE 17.1 Abs. 3a S. 1-2: die urspruengliche Rechnung - auch die E-Rechnung - wird
-- NICHT berichtigt. Kein Storno, keine Gutschrift, keine Belegnummer.
-- Default der Anwendung: keine Berichtigung, weil § 17 Abs. 3 VOB/B dem AN ein Recht auf
-- Buergschaftsabloesung gibt und der Nachweis damit der seltene Ausnahmefall ist.
```

### 2.11 Reverse-Charge-Bescheinigung

```sql
-- UStAE 13b.3 Abs. 3 S. 1, Abs. 4, Abs. 5 S. 1-2; § 13b Abs. 5 S. 2 HS 2 UStG.
CREATE TABLE freistellungsbescheinigung_13b (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  geschaeftspartner_id  uuid NOT NULL REFERENCES geschaeftspartner(id),
  vordruckmuster        text NOT NULL DEFAULT 'USt 1 TG',
  bescheinigung_nr      text,
  ausstellendes_finanzamt text,
  steuernummer_empfaenger text,
  gueltig_von           date NOT NULL,
  gueltig_bis           date NOT NULL,
  -- UStAE 13b.3 Abs. 4: nur mit Wirkung fuer die ZUKUNFT widerrufbar.
  widerrufen_ab         date,
  -- UStAE 13b.3 Abs. 5 S. 2: der Leistende schuldet nur bei Kenntnis oder Kennenmuessen -
  -- der Kenntniszeitpunkt ist vom Widerrufsdatum zu trennen.
  widerruf_bekannt_seit timestamptz,
  beleg_scan_pfad       text,
  erfasst_am            timestamptz NOT NULL DEFAULT now(),
  -- UStAE 13b.3 Abs. 4 S. 1: "auf laengstens drei Jahre zu beschraenken"
  CHECK (gueltig_bis <= gueltig_von + interval '3 years'),
  CHECK (widerrufen_ab IS NULL OR widerrufen_ab >= erfasst_am::date)
);
-- Gueltigkeitstest gegen den LEISTUNGSzeitpunkt (§ 13b Abs. 5 S. 2 HS 2 UStG):
--   beleg.leistungsdatum BETWEEN gueltig_von AND gueltig_bis
--   AND (widerrufen_ab IS NULL OR beleg.leistungsdatum < widerrufen_ab)
```

Die Ableitung des Belegstatus ist eine reine Funktion aus drei Größen (§ 13b Abs. 5 Satz 2, Satz 11 UStG; UStAE 13b.3 Abs. 10) und läuft als Trigger **vor** dem Festschreiben, nicht als Anwendungslogik:

```
rc_status = 'rc_13b_nr4'  ⟺  alle Positionen ist_bauleistung_13b
                          AND gueltige USt 1 TG zum Leistungszeitpunkt
                          AND NOT (ist_jpoer AND bezug_nichtunternehmerisch)
```

### 2.12 Fristen, Prüfbarkeit, Ausschlusswirkung

```sql
-- § 14 Abs. 3, § 17 Abs. 6 Nr. 1 VOB/B rechnen in WERKTAGEN - laenderspezifisch.
CREATE TABLE feiertag (
  datum      date NOT NULL,
  bundesland char(2) NOT NULL,
  ist_werktag boolean NOT NULL,
  bezeichnung text,
  PRIMARY KEY (datum, bundesland)
);
CREATE FUNCTION werktage_addieren(d date, n int, bl char(2)) RETURNS date ...;
-- Kalendertage (21/28/30/60) und Werktage (12/6/18) sind zwei getrennte Arithmetiken.

-- § 288 Abs. 2 BGB i.V.m. § 247 BGB (§ 16 Abs. 5 Nr. 3 VOB/B): keine Hartkodierung.
CREATE TABLE basiszinssatz (gueltig_ab date PRIMARY KEY, satz numeric(6,3) NOT NULL);

-- § 16 Abs. 3 Nr. 1 S. 3 VOB/B: ohne Gruende ist die Ruege unwirksam.
CREATE TABLE pruefbarkeitseinwendung (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id uuid NOT NULL REFERENCES beleg(id),
  erhoben_am date NOT NULL, zugegangen_am date,
  gruende text NOT NULL
);
-- Abgeleitet: pruefbarkeit_praekludiert = keine Einwendung mit erhoben_am <= faellig_am.

-- § 16 Abs. 3 Nr. 2 und Nr. 3 VOB/B: beide Voraussetzungen kumulativ.
CREATE TABLE schlusszahlungsmitteilung (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id uuid NOT NULL REFERENCES auftrag(id),
  beleg_id   uuid REFERENCES beleg(id),
  art        schlusszahlungsmitteilung_art_t NOT NULL,
  schriftlich boolean NOT NULL,
  hinweis_ausschlusswirkung_erteilt boolean NOT NULL,
  zugang_beim_an_am date NOT NULL
);

-- § 16 Abs. 3 Nr. 5 VOB/B: 28 Tage, dann weitere 28 Tage.
CREATE TABLE vorbehalt (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mitteilung_id uuid NOT NULL REFERENCES schlusszahlungsmitteilung(id),
  erklaert_am date,
  frist_1_ende date NOT NULL,       -- zugang_beim_an_am + 28 Tage
  frist_2_ende date NOT NULL,       -- frist_1_ende + 28 Tage
  begruendung_eingereicht_am date,
  pruefbare_rechnung_beleg_id uuid REFERENCES beleg(id)
);
-- Abgeleitet (§ 16 Abs. 3 Nr. 2, 4, 5 VOB/B):
-- nachforderung_ausgeschlossen = (schriftlich AND hinweis_erteilt AND kein Vorbehalt bis
--   frist_1_ende) OR (Vorbehalt erklaert, aber weder Rechnung noch Begruendung bis frist_2_ende)
-- § 16 Abs. 3 Nr. 6 VOB/B: beleg.korrektur_grund IN ('aufmassfehler','rechenfehler',
--   'uebertragungsfehler') hebelt die Ausschlussfristen aus - nur diese drei.

-- § 16 Abs. 1 Nr. 4 VOB/B: Abnahme ist NIE ein Ereignis der Abschlagsrechnung.
CREATE TABLE abnahme (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id uuid NOT NULL REFERENCES auftrag(id),
  typ abnahme_typ_t NOT NULL, abnahme_am date NOT NULL, protokoll_id uuid
);
-- KEIN Feld abnahme_am auf beleg; das Festschreiben einer Abschlagsrechnung startet
-- keine Gewaehrleistungsfrist und loest keinen Gefahruebergang aus.
```

**Fälligkeitsfunktion** (§ 16 Abs. 1 Nr. 3, Abs. 3 Nr. 1, Abs. 5 Nr. 3 VOB/B; § 650g Abs. 4 BGB) — in der Datenbank, nicht in der App:

```sql
CREATE FUNCTION faelligkeit(p_regime vertragsregime_t, p_art text, p_zugang date,
                            p_prueffrist smallint) RETURNS date AS $$
  SELECT CASE
    -- § 16 Abs. 1 Nr. 3 VOB/B
    WHEN p_regime='vob_b' AND p_art='abschlagsrechnung' THEN p_zugang + 21
    -- § 16 Abs. 3 Nr. 1 VOB/B
    WHEN p_regime='vob_b' AND p_art IN ('schlussrechnung','teilschlussrechnung')
         THEN p_zugang + p_prueffrist
    -- § 650g Abs. 4 BGB: Abnahme + prueffaehige Schlussrechnung, 30-Tage-Pruefbarkeitsfrist
    ELSE NULL END; $$ LANGUAGE sql IMMUTABLE;
-- verzug_ab ist NICHT faellig_am: § 16 Abs. 5 Nr. 3 VOB/B -> zugang + 30 (bzw. 60) Tage.
-- Bei Abschlagsrechnungen fallen beide auseinander (21 vs. 30) - haeufigster Modellfehler.
```

### 2.13 Prüfbarkeitsnachweise, Aufmaß, Anlagen

```sql
-- § 14 Abs. 1 S. 3 VOB/B: Mengenberechnungen, Zeichnungen und andere Belege sind BEIZUFUEGEN.
CREATE TABLE beleg_anlage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id uuid NOT NULL REFERENCES beleg(id),
  art text NOT NULL CHECK (art IN ('mengenberechnung','aufmassblatt','zeichnung',
       'stundenlohnzettel','lieferschein','sonstiger_beleg')),
  datei_ref text NOT NULL,
  ist_pflicht boolean NOT NULL DEFAULT false
);
-- Trigger: Festschreiben einer VOB/B-Rechnung ohne Mengen-/Aufmassanlage blockieren
-- oder protokollieren (§ 14 Abs. 1 S. 1 und S. 3 VOB/B).

-- § 14 Abs. 2 VOB/B: Feststellungen moeglichst GEMEINSAM.
CREATE TABLE aufmass (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id uuid NOT NULL REFERENCES auftrag(id),
  aufgenommen_am date NOT NULL,
  gemeinsam boolean NOT NULL DEFAULT false,
  teilnehmer_an text, teilnehmer_ag text, unterschrift_ag_am date
);
CREATE TABLE leistungsnachweis (   -- § 16 Abs. 1 Nr. 1 S. 2 VOB/B: pruefbare Aufstellung
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id uuid NOT NULL REFERENCES auftrag(id),
  stichtag date NOT NULL, aufmass_id uuid REFERENCES aufmass(id)
);
```

### 2.14 Nachträge

```sql
CREATE TABLE nachtrag (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id uuid NOT NULL REFERENCES auftrag(id),
  grund   nachtrag_grund_t  NOT NULL,
  status  nachtrag_status_t NOT NULL DEFAULT 'angeordnet',  -- nur 'vereinbart' ist abrechnungsreif
  -- § 2 Abs. 5 VOB/B: der neue Preis haengt zwingend an einer bestehenden Vertragsposition.
  ursprung_position_id uuid REFERENCES beleg_position(id),
  neuer_einheitspreis  numeric(14,4),
  mehrkosten numeric(14,2), minderkosten numeric(14,2),
  anordnung_am date, anordnung_form anordnung_form_t, vereinbart_am date,
  -- § 2 Abs. 6 Nr. 1 VOB/B: Ankuendigung ist echte Anspruchsvoraussetzung.
  ankuendigung_am date, ankuendigung_form anordnung_form_t, ausfuehrung_beginn_am date,
  -- § 2 Abs. 6 Nr. 2 VOB/B: zwei getrennte Bestandteile, nie in einen Preis kollabieren.
  kalkulation_basis_id uuid, besondere_kosten numeric(14,2),
  -- § 2 Abs. 8 Nr. 2 VOB/B: zwei alternative Heilungstatbestaende.
  anerkannt_am date, angezeigt_am date,
  war_notwendig boolean, entsprach_mutmasslichem_willen boolean,
  preisbildung_nach_absatz text CHECK (preisbildung_nach_absatz IN ('5','6')),
  -- § 650c Abs. 3 S. 1 BGB: 80 % nur vor der Einigung, nur im BGB-Bauvertrag.
  abschlag_ansatz_prozent numeric(5,2) DEFAULT 80,
  -- § 650b Abs. 2 S. 1 BGB: 30 Tage ab Zugang des Aenderungsbegehrens.
  aenderungsbegehren_zugang_am date,
  frist_ablauf_am date,

  -- § 2 Abs. 6 Nr. 1 VOB/B: "Er muss jedoch den Anspruch ... ankuendigen, bevor er mit der
  -- Ausfuehrung der Leistung beginnt."
  CHECK (grund <> 'zusaetzlich_2_6' OR ankuendigung_am IS NOT NULL),
  CHECK (ankuendigung_am IS NULL OR ausfuehrung_beginn_am IS NULL
         OR ankuendigung_am <= ausfuehrung_beginn_am),
  -- § 2 Abs. 5 VOB/B: der neue Preis setzt eine Vertragsposition voraus.
  CHECK (grund <> 'geaendert_2_5' OR ursprung_position_id IS NOT NULL)
  -- KEIN CHECK auf vereinbart_am: § 2 Abs. 5 S. 2 und § 2 Abs. 6 Nr. 2 S. 2 VOB/B sind
  -- reine Ordnungsvorschriften ("soll", "moeglichst") -> nur UI-Warnhinweis.
);

-- § 2 Abs. 8 Nr. 2 VOB/B: Abrechenbarkeit als abgeleitete Groesse.
ALTER TABLE nachtrag ADD COLUMN verguetungsfaehig boolean
  GENERATED ALWAYS AS (
    anerkannt_am IS NOT NULL
    OR (COALESCE(war_notwendig,false) AND COALESCE(entsprach_mutmasslichem_willen,false)
        AND angezeigt_am IS NOT NULL)) STORED;

-- § 650c Abs. 3 S. 3 BGB: Rueckgewaehr und Verzinsung ab Eingang beim Unternehmer.
CREATE TABLE rueckgewaehr_650c (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nachtrag_id uuid NOT NULL REFERENCES nachtrag(id),
  beleg_id uuid REFERENCES beleg(id),
  betrag numeric(14,2) NOT NULL,
  zinsbeginn_am date NOT NULL      -- = Zahlungseingang beim Unternehmer
);
-- Trigger: abschlag_ansatz_prozent nur zulaessig bei auftrag.vertragsregime='bgb_bauvertrag'
-- AND nachtrag.status='angeboten' (§ 650c Abs. 3 S. 1 BGB: "wenn sich die Parteien nicht
-- ueber die Hoehe geeinigt haben").
```

### 2.15 Zahlungsplan, Hinweise, Skonto-Staffeln, Code-Mappings

```sql
-- XRechnung-FAQ: "Eine strukturierte Uebermittlung von Abschlagsplaenen ist ... nicht
-- vorgesehen." -> reine Innen-Datenhaltung am Auftrag, nie eine Belegposition.
CREATE TABLE zahlungsplan_rate (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auftrag_id uuid NOT NULL REFERENCES auftrag(id),
  lfd_nr integer NOT NULL, bezeichnung text NOT NULL,
  faellig_bei text NOT NULL CHECK (faellig_bei IN ('termin','baufortschritt','gewerk_abnahme')),
  faellig_am date, prozentsatz numeric(5,2), betrag_netto numeric(14,2),
  erzeugter_beleg_id uuid REFERENCES beleg(id),
  CHECK (num_nonnulls(prozentsatz, betrag_netto) = 1),
  UNIQUE (auftrag_id, lfd_nr)
);
-- Trigger: SUM(prozentsatz) <= 100 je auftrag_id.

-- BG-1/BT-21/BT-22; UNTDID 4451: 'PMT' fuer Sicherheitseinbehalte, 'AGN' fuer Zahlungsplaene.
CREATE TABLE beleg_hinweis (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id uuid NOT NULL REFERENCES beleg(id),
  betreff_code text NOT NULL CHECK (betreff_code IN ('PMT','AGN')),  -- Codeliste UNTDID 4451
  text text NOT NULL                                                -- BT-22
);

-- BR-DE-18: mehrere Skontostaffeln als mehrere Zeilen; BT-20 ist aber nur 0..1
-- -> beim Export in EIN Textfeld mit Zeilenumbruechen serialisieren.
CREATE TABLE beleg_skonto (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beleg_id uuid NOT NULL REFERENCES beleg(id),
  tage    integer      NOT NULL CHECK (tage > 0),
  prozent numeric(5,2) NOT NULL CHECK (prozent > 0),
  -- BR-DE-18: viertes Segment BASISBETRAG=n, zwingend bei Teilbetragsskonto ("z. B. Material")
  basisbetrag numeric(15,2)
);
-- Formatierung zwingend zweistellig mit Punkt: to_char(prozent,'FM999990.00') -> '2.25'.
-- Deutsche Locale ('2,25') oder '2.3' waeren Validierungsfehler.
-- Trigger: bei beleg.skonto_basis <> 'gesamtbetrag' MUSS basisbetrag gesetzt sein.
-- Trigger (positiver BT-115): faellig_am IS NOT NULL OR zahlungsbedingungen_text IS NOT NULL
--   OR EXISTS(beleg_skonto) - XRechnung Kap. 12 (BT-9 oder BT-20).

-- BT-3 / BR-DE-17: Mapping als Referenzdaten, nicht hartkodiert - der Code haengt am Regime.
CREATE TABLE beleg_art_untdid1001 (
  beleg_art text PRIMARY KEY, code text NOT NULL, bau boolean NOT NULL
);
INSERT INTO beleg_art_untdid1001 VALUES
  ('abschlagsrechnung',      '875', true),   -- Partial construction invoice
  ('teilschlussrechnung',    '876', true),   -- Partial final construction invoice (NEU)
  ('schlussrechnung',        '877', true),   -- Final construction invoice
  ('teilrechnung',           '326', false),  -- Partial invoice
  ('rechnung',               '380', false),  -- Commercial invoice
  ('storno',                 '384', false),  -- Corrected invoice
  ('berichtigung',           '384', false),
  ('gutschrift_kaufmaennisch','381', false), -- Credit note
  ('gutschrift_ustg',        '389', false);  -- Self-billed invoice

-- KoSIT xrechnung-visualization: das DB-Schema bleibt syntaxneutral, der Unterschied liegt
-- nur im Serialisierer -> Mapping als Referenzdaten, Serialisierer daraus testen.
CREATE TABLE en16931_feld (
  bt_id text PRIMARY KEY, bezeichnung text NOT NULL,
  ubl_xpath text, cii_xpath text, kardinalitaet text
);
```

### 2.16 Die vier harten Negativregeln

Diese Regeln sind so wichtig wie die Constraints, weil sie beschreiben, was das System **nicht** tun darf:

1. **Der Einbehalt fasst den Beleg nie an.** `beleg.netto_betrag`, `beleg.steuer_betrag`, `beleg.brutto_betrag` bleiben unberührt; kein Storno, keine Gutschrift, keine Minderung von `beleg_position`. — § 10 Abs. 1 Satz 2 UStG; § 13 Abs. 1 Nr. 1 Buchst. a Satz 1 UStG; UStAE 17.1 Abs. 3a Sätze 1–2.
2. **Skonto erzeugt keinen Beleg.** Keine Belegnummer, kein Storno, keine Gutschrift — nur eine Zeile in `zahlung`. — UStAE 14.5 Abs. 19 Sätze 7–8.
3. **Unterzahlung einer Abschlagsrechnung erzeugt keinen Korrekturbeleg.** — UStAE 14.8 Abs. 5 Sätze 4–5.
4. **Ein Storno der Abschlagsrechnung entfernt sie nicht aus der Absetzungsbasis.** Die Auswahlabfrage darf kein `WHERE beleg.storniert = false` enthalten. — UStAE 14.8 Abs. 9 Satz 1.

---

## 3. Abbildung auf EN 16931

### 3.1 Abschlagsrechnung (Anzahlungsrechnung)

| Feld | BT/BG | Quelle im Schema | Fundstelle |
|---|---|---|---|
| Rechnungsnummer | BT-1 | `beleg.rechnungsnummer` | § 14 Abs. 4 UStG i.V.m. Abs. 5 Satz 1 |
| Ausstellungsdatum | BT-2 | `beleg.ausstellungsdatum` | § 14 Abs. 4 Satz 1 Nr. 6 UStG (Vergleichsdatum) |
| **Rechnungstyp** | **BT-3 = 875** (Partial construction invoice) | `beleg.untdid_1001_code`, eingefroren beim Festschreiben | XRechnung Kap. 11.1; BR-DE-17; FAQ Bauwesen |
| Fälligkeitsdatum | BT-9 | `beleg.faellig_am` (VOB/B: Zugang + 21 Tage) | § 16 Abs. 1 Nr. 3 VOB/B; XRechnung Kap. 12 (BT-9 **oder** BT-20 bei positivem BT-115) |
| Hinweis Voraus-/Anzahlung | BG-1 / BT-21+BT-22 | `beleg.anzahlung_hinweis` bzw. `beleg_hinweis` | UStAE 14.8 Abs. 1 Satz 1 |
| Zahlungsbedingungen / Skonto | BT-20, Format `#SKONTO#TAGE=n#PROZENT=n.nn#[#BASISBETRAG=n#]` | `beleg_skonto` (n Staffeln → **ein** Textfeld) | BR-DE-18 |
| USt-IdNr. Verkäufer | BT-31 | `betrieb.ust_id_nr` | BR-AE-2, BR-CO-9 |
| Steuernummer Verkäufer | BT-32 | `betrieb.steuernummer` | § 14 Abs. 4 Satz 1 Nr. 2 UStG; BR-AE-2 |
| USt-IdNr. Erwerber | BT-48 | `geschaeftspartner.ust_id_nr` | BR-AE-2, BR-CO-9 |
| Buyer legal registration id | BT-47 (Fallback) | `geschaeftspartner.handelsregister_nr` | BR-AE-2 |
| Steueraufschlüsselung | **BG-23** je Kategorie: BT-117 (Steuerbetrag), BT-118 (Kategorie), BT-119 (Satz) | `beleg_steueraufschluesselung` | XRechnung Kap. 12.4.4 |
| Reverse Charge | BT-118 = `AE`, BT-119 = 0, BT-117 = 0, BT-152 = 0 | `rc_status='rc_13b_nr4'` | XRechnung 12.4.4; BR-AE-9 |
| Befreiungsgrund | BT-120 (Text) **und** BT-121 (Code) | `bt120_exemption_text`, `bt121_exemption_code` | XRechnung 12.4.4; BR-AE-10 |
| Positionen | BG-25 mit Positionskennung, `ordnungszahl` in die Positionsebene (BT-126/BT-155) | `beleg_position` | § 14 Abs. 1 Satz 2 VOB/B (Reihenfolge/Bezeichnungen maschinell erhalten) |
| Gesamtbetrag mit USt | BT-112 | `beleg.brutto_betrag` | BR-CO-16 |
| Bereits gezahlt | BT-113 = **0** | `beleg.bereits_gezahlt_brutto` | XRechnung Kap. 11.12 |
| Zahlbetrag | BT-115 | `beleg.restbetrag_brutto` (GENERATED) | BR-28, BR-CO-16 |
| Sicherheitseinbehalt | **nur** BG-1 / BT-21 = `PMT`, BT-22 = Text | `beleg_hinweis` aus `einbehalt_position` | XRechnung-FAQ Bauwesen |
| Abschlagsplan | BG-1 / BT-21 = `AGN` **oder** Anhang BG-24 | `zahlungsplan_rate` → Freitext | XRechnung-FAQ |

**Verboten:** Der Einbehalt darf **nicht** als BG-20 (Document level allowance) oder BG-27/BG-DEX-03 (Positionsnachlass) abgebildet werden (XRechnung-FAQ Bauwesen). BT-115 bleibt vom Einbehalt unberührt.

### 3.2 Schlussrechnung

Zusätzlich bzw. abweichend zur Abschlagsrechnung:

| Feld | BT/BG | Quelle im Schema | Fundstelle |
|---|---|---|---|
| **Rechnungstyp** | **BT-3 = 877** (Final construction invoice); Teilschlussrechnung = **876** | `beleg.untdid_1001_code` | XRechnung Kap. 11.1; FAQ Bauwesen |
| Fälligkeitsdatum | BT-9 = Zugang + 30 (bzw. 60) Tage | `beleg.faellig_am`, `pruef_frist_tage` | § 16 Abs. 3 Nr. 1 VOB/B |
| **Bezug auf Abschlagsrechnungen** | **BG-3** (0..\*), je Abschlag eine Gruppe: **BT-25** = Nummer (Pflicht), **BT-26** = Datum | `beleg_anrechnung.vorbeleg_nummer` / `.vorbeleg_datum` (denormalisierte Kopien) | XRechnung Kap. 11.25 — Anwendungsfall ausdrücklich: *„eine Abschlussrechnung [nimmt] auf vorangegangene Vorauszahlungsrechnungen Bezug"* |
| Bereits gezahlt | **BT-113** = eine Summe | `beleg.bereits_gezahlt_brutto` = `SUM(beleg_anrechnung.angerechneter_brutto)` | XRechnung Kap. 11.12 |
| Rundungsbetrag | BT-114 | `beleg.rundungsbetrag` | BR-CO-16 |
| Zahlbetrag | BT-115 = BT-112 − BT-113 + BT-114, kann **negativ** sein | `beleg.restbetrag_brutto` (GENERATED, BR-CO-16 als DB-Constraint) | BR-CO-16, BR-28 |
| Steueraufschlüsselung bei gemischten Abschlägen | **mehrere BG-23-Gruppen**: eine `AE`-Gruppe (BR-AE-1: genau eine) **und** eine `S`-Gruppe | `beleg_steueraufschluesselung` | BR-AE-1; UStAE 13b.12 Abs. 3 Satz 4 |

**Restrechnung (UStAE 14.8 Abs. 11):** BT-109/BT-112 beziehen sich **nur auf das Restentgelt**; `beleg_anrechnung` ist leer; BT-113 = 0. Die optionale Zusatzangabe nach Satz 3 darf **ausschließlich Nettobeträge** zeigen — ein Steuerausweis auf die Abschläge verwandelte die Restrechnung in eine fehlerhafte Endrechnung (UStAE 14.8 Abs. 10).

### 3.3 Syntaxbindung

| BT/BG | UBL 2.1 | UN/CEFACT CII |
|---|---|---|
| BT-3 | `/Invoice/cbc:InvoiceTypeCode` | `/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:TypeCode` |
| BG-3 | `cac:BillingReference/cac:InvoiceDocumentReference` | `ram:ApplicableHeaderTradeSettlement/ram:InvoiceReferencedDocument` |
| BT-25 | `cbc:ID` | `ram:IssuerAssignedID` |
| BT-26 | `cbc:IssueDate` | `ram:FormattedIssueDateTime/qdt:DateTimeString[@format='102']` |
| BT-113 | `cac:LegalMonetaryTotal/cbc:PrepaidAmount` | `ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TotalPrepaidAmount` |
| BT-114 | `cbc:PayableRoundingAmount` | — |
| BT-115 | `cbc:PayableAmount` | `ram:DuePayableAmount` |

Quelle: KoSIT, `xrechnung-visualization`, `src/xsl/ubl-invoice-xr.xsl` und `src/xsl/cii-xr.xsl`. Das DB-Schema bleibt syntaxneutral — der Unterschied liegt allein im Serialisierer.

---

## 4. Was der Steuerberater bestätigen muss

1. Stellen wir Abschlagsrechnungen grundsätzlich **mit gesondertem Steuerausweis** aus (Voraussetzung für die Absetzungspflicht nach § 14 Abs. 5 Satz 2 UStG)? **Ja/Nein**
2. Wird der Mandant nach **vereinbarten Entgelten** (Soll, § 13 Abs. 1 Nr. 1 Buchst. a UStG) oder nach **vereinnahmten Entgelten** (Ist, § 20 UStG) besteuert? **Soll/Ist**
3. Ist es korrekt, dass wir als `vereinnahmt_am` ausschließlich das **Gutschriftsdatum des Bankkontos** speichern (UStAE 13.6 Abs. 1 Satz 3) und nicht die Wertstellung? **Ja/Nein**
4. Soll das System standardmäßig eine **Endrechnung** (mit Absetzung, § 14 Abs. 5 Satz 2 UStG) oder eine **Restrechnung** (UStAE 14.8 Abs. 11) erzeugen? **Endrechnung/Restrechnung**
5. Welche der Darstellungsvarianten nach UStAE 14.8 Abs. 7 Sätze 2–4 soll Standard sein: einzeln je Anzahlung, Summe Netto+Steuer, Brutto mit enthaltener Steuer, oder ohne Reststeuerbetrag? **Eine Variante nennen**
6. Ist es zutreffend, dass bei **Unterzahlung** einer Abschlagsrechnung **keine** Rechnungsberichtigung erfolgt und die Steuer nur auf den vereinnahmten Betrag entsteht (UStAE 14.8 Abs. 5 Sätze 4–5)? **Ja/Nein**
7. Ist es zutreffend, dass eine **nie bezahlte** Abschlagsrechnung **keine** § 14c Abs. 2 UStG-Steuer auslöst (UStAE 14.8 Abs. 2 Satz 1)? **Ja/Nein**
8. Darf das System eine **Vorausrechnung über 100 %** des Entgelts erstellen und danach weitere Abschlagsrechnungen für denselben Auftrag **sperren** (UStAE 14.8 Abs. 6)? **Ja/Nein**
9. Soll das Festschreiben einer Endrechnung **blockiert** werden, wenn die Summe der abgesetzten Steuerbeträge je Steuersatz nicht exakt der Summe der vereinnahmten Anzahlungssteuer entspricht (UStAE 14.8 Abs. 10 Sätze 1–3)? **Ja/Nein**
10. Führen wir die nach § 14c Abs. 1 UStG geschuldete Steuer in der Voranmeldung **getrennt** von der regulären Umsatzsteuer, mit Entstehungszeitpunkt = Ausgabedatum der Rechnung (§ 13 Abs. 1 Nr. 3 UStG)? **Ja/Nein**
11. Wann liegt bei unseren Aufträgen eine **Teilleistung** (§ 13 Abs. 1 Nr. 1 Buchst. a Satz 3 UStG) statt einer Anzahlung vor — reicht die im Vertrag ausgewiesene Einzelpreisvereinbarung je Gewerk als „gesondert vereinbartes Entgelt"? **Ja/Nein**
12. Ist es zutreffend, dass der **Sicherheitseinbehalt** die Bemessungsgrundlage **nicht** mindert und die Rechnung in voller Höhe zu stellen ist (§ 10 Abs. 1 Satz 2 UStG)? **Ja/Nein**
13. Soll die Berichtigung wegen Uneinbringlichkeit des Einbehalts (§ 17 Abs. 2 Nr. 1 UStG, UStAE 17.1 Abs. 5 Satz 3) im System **standardmäßig deaktiviert** sein und nur nach dokumentiertem Nachweis der Bürgschaftsunmöglichkeit freigeschaltet werden? **Ja/Nein**
14. Ist es zutreffend, dass die **ursprüngliche E-Rechnung** bei einer Änderung der Bemessungsgrundlage **nicht** berichtigt werden muss (UStAE 17.1 Abs. 3a Sätze 1–2)? **Ja/Nein**
15. Genügt für den Reverse-Charge-Nachweis allein die gültige **USt 1 TG**, ohne dass wir den tatsächlichen Bauleistungsanteil des Kunden prüfen oder die Vorlage der Bescheinigung verlangen (UStAE 13b.3 Abs. 5 Satz 1)? **Ja/Nein**
16. Ist es zutreffend, dass Abschläge desselben Auftrags **dauerhaft unterschiedliche** Steuerstatus tragen können und die Schlussrechnung dann zwei Steuerkategorien nebeneinander ausweist (UStAE 13b.12 Abs. 3 Sätze 3–4)? **Ja/Nein**
17. Worauf bezieht sich die 500-EUR-Grenze bei Reparatur-/Wartungsarbeiten — auf den **einzelnen Auftrag**, den **einzelnen Einsatz** oder die **einzelne Belegzeile** (UStAE 13b.2 Abs. 7 Nr. 15)? **Ein Begriff**
18. Soll bei Reverse Charge das Feld BT-120 den Gesetzeswortlaut *„Steuerschuldnerschaft des Leistungsempfängers"* (§ 14a Abs. 5 Satz 1 UStG) tragen und zusätzlich BT-121 mit einem VATEX-Code belegt werden? **Ja/Nein**
19. Ist es zutreffend, dass Skonto **keinen** Korrektur- oder Stornobeleg erzeugt und der betragslose Hinweis genügt (UStAE 14.5 Abs. 19 Sätze 7, 11–12)? **Ja/Nein**
20. Ist es zutreffend, dass die USt-Korrektur aus Skonto in der **Voranmeldungsperiode der Zahlung** zu melden ist, auch wenn die Rechnung aus dem Vorjahr stammt (§ 17 Abs. 1 Satz 8 UStG)? **Ja/Nein**
21. Wenn Skonto vertraglich nur auf den **Materialanteil** gewährt wird: Mindert die Entgeltminderung dann nur die Bemessungsgrundlage dieses Anteils, und wie ist bei gemischten Steuerkategorien (AE/S) aufzuteilen? **Ein Satz**
22. Ist ein einseitiger, **nicht vereinbarter** Skontoabzug des Auftraggebers als offene Forderung zu führen (nicht als Entgeltminderung), § 16 Abs. 5 Nr. 2 VOB/B? **Ja/Nein**
23. Kennen Sie die Rn. 47 und 48 des BMF-Schreibens vom 15.10.2024 (BStBl I S. 1320): Ist die Absetzung der Anzahlungen bei E-Rechnungen als **Anhang** oder **separate Zusammenstellung** (UStAE 14.8 Abs. 8 Nrn. 2–3) zulässig, oder müssen die Beträge zwingend im strukturierten Teil stehen? **Ein Satz**
24. Genügt für die Absetzung nach § 14 Abs. 5 Satz 2 UStG in einer XRechnung die Summe in **BT-113** zusammen mit den **BG-3**-Referenzen (BT-25/BT-26), oder verlangen Sie eine zusätzliche Darstellung je Abschlag? **Ein Satz**

---

## 5. Was ungeklärt bleibt

1. **Der zentrale offene Punkt: kein strukturiertes Zielfeld für die Absetzung je Abschlag.** BT-113 ist ausdrücklich *„eine einzige Summe"* (XRechnung Kap. 11.12), BG-3 trägt *keinen Betrag* (Kap. 11.25). Gleichzeitig verlangt BMF v. 15.10.2025 Rn. 35, dass **alle** Pflichtangaben — also auch die nach § 14 Abs. 5 Satz 2 UStG abzusetzenden Teilentgelte **und die darauf entfallenden Steuerbeträge** — im strukturierten Teil stehen. Eine Zuordnung, die diese Lücke schließt, konnte aus den zugelassenen Primärquellen nicht belegt werden; eine kursierende KoSIT/FeRD-Zuordnung ist in der Gegenprüfung durchgefallen und wird hier bewusst nicht verwendet. **Konsequenz für das Produkt:** Frage 24 an den Steuerberater; bis zur Klärung ist die Absetzung in `beleg_anrechnung` vollständig vorzuhalten, damit jede spätere Darstellungsform daraus gerendert werden kann.
2. **Rn. 47 und 48 des BMF-Schreibens vom 15.10.2024** (BStBl I S. 1320) wurden nicht geprüft. UStAE 14.8 Abs. 7 Satz 5 verweist für E-Rechnungsfälle ausdrücklich darauf. Solange sie nicht vorliegen, sind die Darstellungsvarianten `anhang` und `separate_zusammenstellung` für E-Rechnungen per CHECK gesperrt — **eine bewusst konservative [ANNAHME]**, die sich nach Prüfung lockern lassen könnte.
3. **ZUGFeRD/CII-Kardinalität von `ram:InvoiceReferencedDocument`.** Ob das ZUGFeRD-EN16931-Profil dieses Element mehrfach zulässt, konnte nicht aus einer Primärquelle belegt werden (die Spezifikation ist nur nach Registrierung abrufbar). Eine Schlussrechnung referenziert typischerweise n Abschläge. Das DB-Schema (`beleg_anrechnung` 1:n) ist davon unberührt — betroffen wäre nur der CII-Serialisierer. **Vor Implementierung am ZUGFeRD-XSD verifizieren.**
4. **Die Prozentsätze 5 % (Vertragserfüllung) und 3 % (Mängelansprüche)** stammen aus § 9c VOB/A. Die VOB/A stand nicht auf der Primärquellenliste und der amtliche Text lag nicht vor. Deshalb: **keine** Prozentsatz-Defaults im Schema; `sicherheitssumme_soll` ist ein pro Vertrag erfasster Betrag. Für private Auftraggeber — den Regelfall dieses Produkts — wären die Sätze ohnehin reine Vertragspraxis.
5. **Die Bemessungsgrundlage je BG-23-Gruppe** ist im Schema als Spalte vorgesehen, der zugehörige BT-Bezeichner konnte aus den geprüften Quellenzitaten nicht belegt werden. Vor der Implementierung des Serialisierers am EN-16931-Feldkatalog nachziehen.
6. **Der Umkehrschluss „Einbehalt im Regelfall vom Bruttobetrag"** ist eine Ableitung aus dem Normzweck von § 17 Abs. 6 Nr. 1 Satz 2 VOB/B, **nicht** wörtlich normiert. Deshalb ist `einbehalt_basis` eine überschreibbare Spalte, kein hart erzwungener Default. **[ANNAHME]**
7. **Der Begriff „Werktag"** in § 14 Abs. 3, § 17 Abs. 6 Nr. 1 VOB/B ist in den geprüften Quellen nicht definiert. Ob der Samstag mitzählt, ist offen. Die Funktion `werktage_addieren()` und die Tabelle `feiertag` bilden die Mechanik ab; die **Definition** muss vor Produktivsetzung geklärt und als Parameter geführt werden.
8. **Die materielle Abgrenzung Teilrechnung (326) / Teilschlussrechnung (876).** Der Codewert ist über BR-DE-17 und die KoSIT-FAQ belegt, die umsatzsteuerliche Abgrenzung dagegen nur mittelbar über § 13 Abs. 1 Nr. 1 Buchst. a Satz 3 UStG (gesondert vereinbartes Entgelt). Welche Sachverhalte im Handwerksalltag darunterfallen, ist Frage 11 an den Steuerberater.
9. **Der volle Pflichtangabenkatalog des § 14 Abs. 4 Satz 1 UStG** wurde nur für die Nummern 2, 6, 7 und 8 wörtlich belegt. Die übrigen Nummern (insbesondere die fortlaufende Nummer, Nr. 4) sind im Schema als NOT-NULL-Spalten vorgesehen, aber in dieser Recherche **nicht** zitiert.
10. **Die Lückenlosigkeit des Nummernkreises** ist eine Vorgabe des bestehenden Modells. Sie wurde in dieser Recherche **nicht** an einer Primärquelle (AO/GoBD) verifiziert. Alle daraus abgeleiteten Negativregeln („keine Nummer für Storni ohne Rechtsgrund verbrauchen") ruhen deshalb auf einer Produktentscheidung, nicht auf einem geprüften Paragrafen. **[ANNAHME]**
11. **Die dreiwertige Vereinheitlichung des Vertragsregimes** und die Zusammenlegung von `abschlag_absetzung` und `beleg_anrechnung` sind Modellierungsentscheidungen dieses Entwurfs. Die Quellen fordern die getrennten Sachverhalte, nicht die konkreten Tabellennamen oder Enum-Werte. **[ANNAHME]**
12. **Zwei Aussagen dieser Recherche standen bei 2:1** statt 3:0 in der Gegenprüfung: (a) die Reichweite von § 14 Abs. 5 Satz 1 UStG für die Pflichtfeld-Vererbung, (b) die Bindung der 500-EUR-Grenze an „den einzelnen Umsatz", (c) BT-113 als einzige Summe, (d) die BT-3-Codewahl, (e) die BR-DE-18-Skontosyntax, (f) die Nicht-Erforderlichkeit einer Rechnungsberichtigung beim Skonto. Sie sind jeweils wörtlich belegt, tragen aber eine geringere interne Bestätigungsdichte; die Fragen 1, 17, 19 und 24 adressieren genau diese Punkte.

---

## 6. Verworfen — nicht verwenden
Fuenf Aussagen sind in der dreifachen Gegenpruefung durchgefallen. Sie stehenhier, damit sie niemand aus einer anderen Quelle wieder einsammelt und fuerbelegt haelt. Das Votum nennt Zustimmungen zu Ablehnungen.

**[0:3] ABLOESUNG DURCH BUERGSCHAFT: Der Auftragnehmer hat ein einseitiges Wahl- und Austauschrecht - er kann einen bereits einbehaltenen Geldbetrag jederzeit durch eine Buergschaft ersetzen und die Auszahlun**

*Angebliche Fundstelle:* § 17 Abs. 3 und § 17 Abs. 4 VOB/B (Ausgabe 2016)

**[1:2] EN 16931 / XRechnung KENNEN KEIN EINBEHALTSFELD - und die beiden naheliegenden Auswege sind beide falsch. Die Gruppe DOCUMENT LEVEL ALLOWANCES (BG-20) darf NICHT verwendet werden, weil ihre Elemente z**

*Angebliche Fundstelle:* XRechnung 3.0.2 (KoSIT, Fassung vom 20.06.2024), Abschnitt 11.10 'Gruppe DOCUMENT LEVEL ALLOWANCES' (BG-20) und Abschnitt 11.12 'Gruppe DOCUMENT TOTALS' (BG-22), Elemente BT-112, BT-113, BT-114, BT-115; Geschaeftsregel BR-CO-16 bzw. BR-DEX-09

**[1:2] BT-113 wirkt NICHT auf die Bemessungsgrundlage: BT-109/BT-110/BT-112 werden aus Positionen und Dokument-Nachlaessen/-Zuschlaegen berechnet (BR-CO-13), BT-113 greift erst danach in BT-115. Wuerde man e**

*Angebliche Fundstelle:* XRechnung 3.0.2, Kap. 12.2 Integritaetsbedingungen, BR-CO-11 und BR-CO-13; Kap. 11.10 "Gruppe DOCUMENT LEVEL ALLOWANCES" (BG-20), Abschnitt "Hinweise"

**[1:2] KoSIT und FeRD ordnen §14 Abs. 5 Satz 2 UStG (Absetzung vereinnahmter Teilentgelte in der Endrechnung) gemeinsam den Feldern BG-22 mit BT-113 und BT-115 sowie BG-1 INVOICE NOTE und BG-24 ADDITIONAL SU**

*Angebliche Fundstelle:* KoSIT/FeRD, "Empfehlungen zu Pflichtangaben in einer E-Rechnung, Teil I: Pflichtangaben gemaess Umsatzsteuergesetz", Stand 25.07.2025, Zeilen zu §14 Abs. 5 S. 2 UStG und "Beispiele fuer Gestaltung von Anzahlungs- und Endrechnungen"

**[0:3] Zur Modellierungsfrage 'eigener Beleg oder Positionen': Beides, auf getrennten Ebenen. VERTRAGLICH ist der Nachtrag ein eigenstaendiger Vorgang mit eigener Belegkette - § 650b Abs. 1 Satz 2 BGB begrue**

*Angebliche Fundstelle:* § 650b Abs. 1 Satz 2 BGB; VOB/B § 2 Abs. 6 Nr. 1; Spezifikation Standard XRechnung 3.0.2, Geschaeftsregel BR-DE-17 (Kap. 12, Nationale Geschaeftsregeln)

Bemerkenswert ist die Haeufung: vier der fuenf betreffen die Abbildung von
Einbehalten und Anzahlungen auf EN-16931-Felder. Genau dort liegt auch der
zentrale offene Punkt aus Abschnitt 5. Die Norm hat an dieser Stelle
schlicht eine Luecke, und wer sie mit einer plausiblen Feldzuordnung
schliesst, tut das ohne Deckung durch die Spezifikation.
