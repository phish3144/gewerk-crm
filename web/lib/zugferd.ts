// ZUGFeRD 2.0.1, Profil BASIC: die Rechnung als Datensatz.
//
// Das Format ist UN/CEFACT Cross Industry Invoice (CII) - dieselbe Syntax, die
// EN 16931 und damit die deutsche E-Rechnungspflicht verlangt. Erzeugt wird es
// aus genau denselben Feldern wie die Sichtfassung; es gibt keine zweite
// Datenhaltung fuer "die XML-Variante", weil zwei Quellen frueher oder spaeter
// auseinanderlaufen und dann niemand weiss, welche gilt.
//
// Bewusst von Hand geschrieben statt ueber eine Bibliothek: die Reihenfolge der
// Elemente ist in CII bindend, ein Schema-Validator weist jede Abweichung ab,
// und eine Bibliothek, die das verbirgt, macht die Fehlersuche schwerer statt
// leichter.

export type RechnungsDaten = {
  nummer: string;
  datum: string;                 // ISO
  leistungsdatum: string | null; // BT-72, § 14 Abs. 4 Nr. 6 UStG
  art: string;
  betreff: string | null;
  waehrung: string;

  verkaeufer: {
    name: string;
    strasse: string | null;
    plz: string | null;
    ort: string | null;
    ust_id: string | null;
    steuernummer: string | null;
  };
  kaeufer: {
    name: string;
    strasse: string | null;
    plz: string | null;
    ort: string | null;
    ust_id: string | null;
  };

  positionen: Array<{
    nr: number;
    bezeichnung: string;
    menge: number;
    einheit: string;
    einzelpreis: number;
    gesamt: number;
    steuersatz: number;
  }>;

  // Je Steuersatz eine Zeile - eine Bruttosumme genuegt der Norm nicht.
  steuergruppen: Array<{ satz: number; netto: number; steuer: number }>;

  netto: number;
  steuer: number;
  brutto: number;
  // Bereits vereinnahmte und abgesetzte Teilentgelte (BT-113).
  angerechnet: number;
  faellig: number;
  faellig_am: string | null;
  reverse_charge: boolean;
};

function x(text: string | null | undefined): string {
  if (text == null) return "";
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// CII will Punkt als Dezimalzeichen und feste Nachkommastellen.
function z(wert: number, stellen = 2): string {
  return (Math.round(wert * 10 ** stellen) / 10 ** stellen).toFixed(stellen);
}

// Format 102: JJJJMMTT, ohne Trennzeichen.
function datum102(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}`;
}

// Rechnungsart nach UNTDID 1001. 380 ist die gewoehnliche Rechnung; 386 die
// Vorauszahlungsrechnung, die fuer Abschlaege gilt.
function typcode(art: string): string {
  return art === "abschlagsrechnung" ? "386" : "380";
}

// UN/ECE Recommendation 20 - CII kennt keine freien Einheiten. Was nicht in der
// Liste steht, wird zu C62 ("Stueck"), und das ist ehrlicher als ein erfundener
// Code, den kein Empfaengersystem kennt.
const EINHEITEN: Record<string, string> = {
  stk: "H87", "stk.": "H87", st: "H87", stück: "H87", stueck: "H87",
  h: "HUR", std: "HUR", "std.": "HUR", stunde: "HUR", stunden: "HUR", akh: "HUR",
  m: "MTR", lfm: "MTR", meter: "MTR",
  "m²": "MTK", m2: "MTK", qm: "MTK",
  "m³": "MTQ", m3: "MTQ",
  kg: "KGM", t: "TNE", l: "LTR", liter: "LTR",
  tag: "DAY", tage: "DAY", pauschal: "C62", psch: "C62",
};

export function einheitscode(einheit: string): string {
  return EINHEITEN[einheit.trim().toLowerCase()] ?? "C62";
}

// Steuerkategorie nach UNTDID 5305. S = Regelsatz, Z = Nullsatz,
// AE = Steuerschuldnerschaft des Leistungsempfaengers (§ 13b UStG).
function kategorie(satz: number, rc: boolean): string {
  if (rc) return "AE";
  return satz > 0 ? "S" : "Z";
}

export function zugferdXml(r: RechnungsDaten): string {
  const rc = r.reverse_charge;

  const positionen = r.positionen
    .map(
      (p) => `    <ram:IncludedSupplyChainTradeLineItem>
      <ram:AssociatedDocumentLineDocument>
        <ram:LineID>${p.nr}</ram:LineID>
      </ram:AssociatedDocumentLineDocument>
      <ram:SpecifiedTradeProduct>
        <ram:Name>${x(p.bezeichnung)}</ram:Name>
      </ram:SpecifiedTradeProduct>
      <ram:SpecifiedLineTradeAgreement>
        <ram:NetPriceProductTradePrice>
          <ram:ChargeAmount>${z(p.einzelpreis, 4)}</ram:ChargeAmount>
        </ram:NetPriceProductTradePrice>
      </ram:SpecifiedLineTradeAgreement>
      <ram:SpecifiedLineTradeDelivery>
        <ram:BilledQuantity unitCode="${einheitscode(p.einheit)}">${z(p.menge, 4)}</ram:BilledQuantity>
      </ram:SpecifiedLineTradeDelivery>
      <ram:SpecifiedLineTradeSettlement>
        <ram:ApplicableTradeTax>
          <ram:TypeCode>VAT</ram:TypeCode>
          <ram:CategoryCode>${kategorie(p.steuersatz, rc)}</ram:CategoryCode>
          <ram:RateApplicablePercent>${z(rc ? 0 : p.steuersatz)}</ram:RateApplicablePercent>
        </ram:ApplicableTradeTax>
        <ram:SpecifiedTradeSettlementLineMonetarySummation>
          <ram:LineTotalAmount>${z(p.gesamt)}</ram:LineTotalAmount>
        </ram:SpecifiedTradeSettlementLineMonetarySummation>
      </ram:SpecifiedLineTradeSettlement>
    </ram:IncludedSupplyChainTradeLineItem>`,
    )
    .join("\n");

  const steuerzeilen = r.steuergruppen
    .map(
      (g) => `      <ram:ApplicableTradeTax>
        <ram:CalculatedAmount>${z(g.steuer)}</ram:CalculatedAmount>
        <ram:TypeCode>VAT</ram:TypeCode>${
          rc
            ? `
        <ram:ExemptionReason>Steuerschuldnerschaft des Leistungsempfaengers (§ 13b UStG)</ram:ExemptionReason>`
            : ""
        }
        <ram:BasisAmount>${z(g.netto)}</ram:BasisAmount>
        <ram:CategoryCode>${kategorie(g.satz, rc)}</ram:CategoryCode>
        <ram:RateApplicablePercent>${z(rc ? 0 : g.satz)}</ram:RateApplicablePercent>
      </ram:ApplicableTradeTax>`,
    )
    .join("\n");

  return `<?xml version="1.0" encoding="UTF-8"?>
<rsm:CrossIndustryInvoice
    xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
    xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
    xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
  <rsm:ExchangedDocumentContext>
    <ram:GuidelineSpecifiedDocumentContextParameter>
      <ram:ID>urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic</ram:ID>
    </ram:GuidelineSpecifiedDocumentContextParameter>
  </rsm:ExchangedDocumentContext>
  <rsm:ExchangedDocument>
    <ram:ID>${x(r.nummer)}</ram:ID>
    <ram:TypeCode>${typcode(r.art)}</ram:TypeCode>
    <ram:IssueDateTime>
      <udt:DateTimeString format="102">${datum102(r.datum)}</udt:DateTimeString>
    </ram:IssueDateTime>${
      r.betreff
        ? `
    <ram:IncludedNote>
      <ram:Content>${x(r.betreff)}</ram:Content>
    </ram:IncludedNote>`
        : ""
    }${
      rc
        ? `
    <ram:IncludedNote>
      <ram:Content>Steuerschuldnerschaft des Leistungsempfaengers (§ 13b UStG)</ram:Content>
    </ram:IncludedNote>`
        : ""
    }
  </rsm:ExchangedDocument>
  <rsm:SupplyChainTradeTransaction>
${positionen}
    <ram:ApplicableHeaderTradeAgreement>
      <ram:SellerTradeParty>
        <ram:Name>${x(r.verkaeufer.name)}</ram:Name>
        <ram:PostalTradeAddress>
          <ram:PostcodeCode>${x(r.verkaeufer.plz)}</ram:PostcodeCode>
          <ram:LineOne>${x(r.verkaeufer.strasse)}</ram:LineOne>
          <ram:CityName>${x(r.verkaeufer.ort)}</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>${
          r.verkaeufer.ust_id
            ? `
        <ram:SpecifiedTaxRegistration>
          <ram:ID schemeID="VA">${x(r.verkaeufer.ust_id)}</ram:ID>
        </ram:SpecifiedTaxRegistration>`
            : ""
        }${
          r.verkaeufer.steuernummer
            ? `
        <ram:SpecifiedTaxRegistration>
          <ram:ID schemeID="FC">${x(r.verkaeufer.steuernummer)}</ram:ID>
        </ram:SpecifiedTaxRegistration>`
            : ""
        }
      </ram:SellerTradeParty>
      <ram:BuyerTradeParty>
        <ram:Name>${x(r.kaeufer.name)}</ram:Name>
        <ram:PostalTradeAddress>
          <ram:PostcodeCode>${x(r.kaeufer.plz)}</ram:PostcodeCode>
          <ram:LineOne>${x(r.kaeufer.strasse)}</ram:LineOne>
          <ram:CityName>${x(r.kaeufer.ort)}</ram:CityName>
          <ram:CountryID>DE</ram:CountryID>
        </ram:PostalTradeAddress>${
          r.kaeufer.ust_id
            ? `
        <ram:SpecifiedTaxRegistration>
          <ram:ID schemeID="VA">${x(r.kaeufer.ust_id)}</ram:ID>
        </ram:SpecifiedTaxRegistration>`
            : ""
        }
      </ram:BuyerTradeParty>
    </ram:ApplicableHeaderTradeAgreement>
    <ram:ApplicableHeaderTradeDelivery>${
      r.leistungsdatum
        ? `
      <ram:ActualDeliverySupplyChainEvent>
        <ram:OccurrenceDateTime>
          <udt:DateTimeString format="102">${datum102(r.leistungsdatum)}</udt:DateTimeString>
        </ram:OccurrenceDateTime>
      </ram:ActualDeliverySupplyChainEvent>`
        : ""
    }
    </ram:ApplicableHeaderTradeDelivery>
    <ram:ApplicableHeaderTradeSettlement>
      <ram:InvoiceCurrencyCode>${x(r.waehrung)}</ram:InvoiceCurrencyCode>
${steuerzeilen}${
    r.faellig_am
      ? `
      <ram:SpecifiedTradePaymentTerms>
        <ram:DueDateDateTime>
          <udt:DateTimeString format="102">${datum102(r.faellig_am)}</udt:DateTimeString>
        </ram:DueDateDateTime>
      </ram:SpecifiedTradePaymentTerms>`
      : ""
  }
      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
        <ram:LineTotalAmount>${z(r.netto)}</ram:LineTotalAmount>
        <ram:TaxBasisTotalAmount>${z(r.netto)}</ram:TaxBasisTotalAmount>
        <ram:TaxTotalAmount currencyID="${x(r.waehrung)}">${z(r.steuer)}</ram:TaxTotalAmount>
        <ram:GrandTotalAmount>${z(r.brutto)}</ram:GrandTotalAmount>
        <ram:TotalPrepaidAmount>${z(r.angerechnet)}</ram:TotalPrepaidAmount>
        <ram:DuePayableAmount>${z(r.faellig)}</ram:DuePayableAmount>
      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
    </ram:ApplicableHeaderTradeSettlement>
  </rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>
`;
}
