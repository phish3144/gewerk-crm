# Datenmodell

Postgres 17 auf Supabase, `eu-central-1`. Mandantentrennung über RLS.

> ⚠️ **Der Rechnungsteil ist noch nicht entscheidungsreif.** Sämtliche
> recherchierten Aussagen zu VOB/B (§ 14 Prüfbarkeit, § 16 Zahlungsfristen,
> § 17 Einbehalte), zu Abschlagsrechnungen und zu § 13b UStG Reverse-Charge
> sind in der Verifikation **durchgefallen**. Das Schema unten bildet die
> Struktur ab, die Semantik ist vor dem Freeze gegen Primärquellen und einen
> Steuerberater zu prüfen. Siehe [offene-fragen.md](offene-fragen.md).

---

## Grundprinzipien

1. **Jede Tabelle trägt `betrieb_id`** — keine Ausnahme. Mandantentrennung ist eine Schema-Invariante, kein Anwendungsdetail.
2. **Belege sind unveränderlich, sobald sie festgeschrieben sind.** Änderungen erzeugen Nachfolgeversionen, keine Updates.
3. **Nummernkreise sind lückenlos und werden in der Datenbank vergeben** — nie im Anwendungscode.
4. **Geldbeträge sind `numeric(14,2)`, niemals `float`.** Mengen `numeric(14,4)`.
5. **Zeitstempel sind `timestamptz`**, Anzeige in `Europe/Berlin`.

---

## Kern-Entitäten

```
betrieb (Mandant)
  ├── benutzer ──────── mitarbeiter
  ├── kunde ─────────── ansprechpartner
  ├── projekt (Baustelle)
  │     ├── beleg (Angebot → Auftrag → Rechnung)
  │     │     └── beleg_position
  │     ├── dokumentation (Fotos, Notizen, Aufmaß)
  │     ├── einsatz (Disposition)
  │     └── zeiteintrag
  ├── artikel ───────── lieferant
  └── nummernkreis
```

### Belegkette

Ein **einziger** `beleg`-Typ mit Diskriminator statt getrennter Tabellen —
Angebot, Auftragsbestätigung, Abschlags-, Teil- und Schlussrechnung teilen
Positionen, Summenlogik und Nummernkreise.

```sql
create type beleg_art as enum (
  'angebot', 'auftrag', 'abschlagsrechnung',
  'teilrechnung', 'schlussrechnung', 'gutschrift', 'storno'
);

create type beleg_status as enum (
  'entwurf',        -- änderbar
  'festgeschrieben',-- unveränderlich, Nummer vergeben
  'versendet', 'angenommen', 'abgelehnt',
  'bezahlt', 'storniert'
);

create table beleg (
  id              uuid primary key default gen_random_uuid(),
  betrieb_id      uuid not null references betrieb(id),
  projekt_id      uuid references projekt(id),
  kunde_id        uuid not null references kunde(id),
  art             beleg_art not null,
  status          beleg_status not null default 'entwurf',
  nummer          text,                    -- NULL bis festgeschrieben
  vorgaenger_id   uuid references beleg(id), -- Angebot→Auftrag→Rechnung
  storniert_durch uuid references beleg(id),
  datum           date not null default current_date,
  leistungsdatum  date,                    -- §14 UStG Pflichtangabe
  netto           numeric(14,2) not null default 0,
  steuer          numeric(14,2) not null default 0,
  brutto          numeric(14,2) not null default 0,
  festgeschrieben_am timestamptz,
  erstellt_von    uuid not null references benutzer(id),
  erstellt_am     timestamptz not null default now(),

  -- Eine festgeschriebene Rechnung MUSS eine Nummer haben und umgekehrt
  constraint nummer_bei_festschreibung check (
    (status = 'entwurf' and nummer is null)
    or (status <> 'entwurf' and nummer is not null)
  )
);
```

### Positionen mit getrennten Kostenanteilen

Handwerksspezifisch: eine Position trägt **Lohn-, Material- und
Fremdleistungsanteil getrennt**. Ohne diese Trennung ist keine Nachkalkulation
und keine Deckungsbeitragsrechnung möglich — und genau das ist bei plancraft
erst ab dem Pro-Tarif (139,90 €/Monat) enthalten.

```sql
create table beleg_position (
  id            uuid primary key default gen_random_uuid(),
  betrieb_id    uuid not null references betrieb(id),
  beleg_id      uuid not null references beleg(id) on delete cascade,
  position_nr   integer not null,
  art           text not null,          -- 'leistung' | 'material' | 'lohn' | 'text' | 'titel'
  artikel_id    uuid references artikel(id),
  bezeichnung   text not null,
  menge         numeric(14,4) not null default 1,
  einheit       text not null default 'Stk',
  einzelpreis   numeric(14,2) not null default 0,
  rabatt_prozent numeric(5,2) not null default 0,
  steuersatz    numeric(5,2) not null default 19,

  -- Kalkulationsanteile
  lohn_anteil          numeric(14,2) not null default 0,
  material_anteil      numeric(14,2) not null default 0,
  fremdleistung_anteil numeric(14,2) not null default 0,
  lohn_minuten         integer not null default 0,

  gaeb_position text,                   -- Rückverweis ins Leistungsverzeichnis
  unique (beleg_id, position_nr)
);
```

### Subunternehmer als planbare Ressource

Direkt aus der Wettbewerbsanalyse: HERO kann Subunternehmer **nicht** in die
Einsatzplanung einplanen — ein dokumentierter Kritikpunkt. Deshalb ist
`einsatz.ressource` polymorph statt auf Mitarbeiter beschränkt.

```sql
create table einsatz (
  id           uuid primary key default gen_random_uuid(),
  betrieb_id   uuid not null references betrieb(id),
  projekt_id   uuid not null references projekt(id),
  ressource_art text not null,          -- 'mitarbeiter' | 'subunternehmer' | 'geraet'
  mitarbeiter_id    uuid references mitarbeiter(id),
  subunternehmer_id uuid references lieferant(id),
  von          timestamptz not null,
  bis          timestamptz not null,
  check (bis > von),
  check (
    (ressource_art = 'mitarbeiter'    and mitarbeiter_id is not null)
    or (ressource_art = 'subunternehmer' and subunternehmer_id is not null)
    or (ressource_art = 'geraet')
  )
);
```

---

## GoBD-Unveränderbarkeit

Drei Mechanismen. Alle in der Datenbank, keiner im Anwendungscode.

### 1. Festgeschriebene Belege sind schreibgeschützt

```sql
create or replace function beleg_unveraenderlich()
returns trigger language plpgsql as $$
begin
  if old.status <> 'entwurf' then
    -- Nur der Übergang zu einem Folgestatus ist erlaubt, nie inhaltliche Änderung
    if new.netto <> old.netto or new.brutto <> old.brutto
       or new.nummer <> old.nummer or new.datum <> old.datum
       or new.kunde_id <> old.kunde_id then
      raise exception
        'Beleg % ist festgeschrieben und inhaltlich unveraenderlich (GoBD). '
        'Korrektur nur ueber Storno + Neuausstellung.', old.nummer;
    end if;
  end if;
  return new;
end $$;

create trigger trg_beleg_unveraenderlich
  before update on beleg
  for each row execute function beleg_unveraenderlich();
```

Positionen festgeschriebener Belege werden analog gesperrt (`UPDATE` und
`DELETE`). **Korrektur erfolgt ausschließlich über Storno + Neuausstellung** —
das ist der GoBD-konforme Weg und zugleich der, den Prüfer erwarten.

### 2. Lückenlose Nummernkreise

Ein `sequence` reicht **nicht**: Postgres-Sequences verlieren Werte bei
Rollback, und eine Lücke im Rechnungsnummernkreis ist ein GoBD-Befund.

```sql
create table nummernkreis (
  betrieb_id  uuid not null references betrieb(id),
  art         beleg_art not null,
  jahr        integer not null,
  praefix     text not null default '',
  naechste    integer not null default 1,
  primary key (betrieb_id, art, jahr)
);

create or replace function naechste_nummer(p_betrieb uuid, p_art beleg_art)
returns text language plpgsql as $$
declare v_jahr integer := extract(year from current_date);
        v_nr integer; v_praefix text;
begin
  -- FOR UPDATE serialisiert konkurrierende Festschreibungen: keine Lücke, kein Duplikat
  select naechste, praefix into v_nr, v_praefix
    from nummernkreis
   where betrieb_id = p_betrieb and art = p_art and jahr = v_jahr
     for update;

  if not found then
    insert into nummernkreis (betrieb_id, art, jahr, naechste)
    values (p_betrieb, p_art, v_jahr, 2)
    returning 1, praefix into v_nr, v_praefix;
  else
    update nummernkreis set naechste = naechste + 1
     where betrieb_id = p_betrieb and art = p_art and jahr = v_jahr;
  end if;

  return format('%s%s-%s', v_praefix, v_jahr, lpad(v_nr::text, 5, '0'));
end $$;
```

> Die Nummer wird **erst bei der Festschreibung** vergeben, nie beim Entwurf.
> Ein verworfener Entwurf hinterlässt damit keine Lücke.

### 3. Append-only Journal

```sql
create table journal (
  id          bigserial primary key,
  betrieb_id  uuid not null,
  tabelle     text not null,
  datensatz_id uuid not null,
  aktion      text not null,           -- 'insert' | 'update' | 'delete'
  vorher      jsonb,
  nachher     jsonb,
  benutzer_id uuid,
  erfasst_am  timestamptz not null default now()
);

revoke update, delete on journal from public, authenticated, anon;
```

Ein `AFTER`-Trigger auf allen belegführenden Tabellen schreibt hier hinein.
`UPDATE` und `DELETE` sind auf DB-Ebene entzogen — auch für die Anwendung.

---

## RLS — die vier Pflichtmuster

Die Benchmarks stammen von Supabase selbst. **Ohne diese Muster kippt die
Mandantentrennung in Timeouts** (belegte Messung: 9.000 ms bzw. > 3 Minuten).

```sql
-- Betriebszugehörigkeit einmal zentral, STABLE für Plan-Caching
create or replace function meine_betriebe()
returns setof uuid language sql stable security definer as $$
  select betrieb_id from benutzer_betrieb where benutzer_id = (select auth.uid())
$$;

alter table beleg enable row level security;

create policy beleg_mandant on beleg
  for all
  to authenticated                          -- (3) Rolle in TO-Klausel: 170 ms → <0,1 ms
  using  (betrieb_id = any (array(select meine_betriebe())))  -- (1)+(2)
  with check (betrieb_id = any (array(select meine_betriebe())));

create index on beleg (betrieb_id);         -- (4) wirkt NUR mit gewrappter Funktion
```

| # | Muster | Messung |
|---|---|---|
| 1 | Auth-Funktion in Sub-SELECT wrappen: `(select auth.uid())` statt `auth.uid()` | 179 ms → **9 ms** |
| 2 | Join-Richtung: Zeilenspalte gegen feste Menge prüfen, nicht umgekehrt | 9.000 ms → **20 ms** |
| 3 | `TO authenticated` statt Policy ohne Rolle | 170 ms → **< 0,1 ms** |
| 4 | Index auf `betrieb_id` **plus** `ARRAY(select …)`-Wrapping | Timeout > 3 min → **~2 ms** |

**Zusätzlich clientseitig filtern**, nicht nur auf RLS verlassen:
`.eq('betrieb_id', betriebId)` → 171 ms → 9 ms.

> Ab ~10.000 Betrieben pro Nutzer ist die `IN`-Liste zu analysieren. Für die
> Zielgruppe (ein Nutzer gehört zu 1–2 Betrieben) unkritisch.

---

## Baustellendokumentation

```sql
create table dokumentation (
  id           uuid primary key,        -- client-generiert! (Offline-Idempotenz)
  betrieb_id   uuid not null references betrieb(id),
  projekt_id   uuid not null references projekt(id),
  art          text not null,           -- 'foto' | 'notiz' | 'aufmass' | 'sprachnotiz'
  r2_key       text,                    -- Objektschlüssel in R2, nicht die Datei selbst
  text         text,
  aufmass      jsonb,                   -- {laenge, breite, hoehe, formel, ergebnis}
  erfasst_am   timestamptz not null,    -- Zeitpunkt auf der Baustelle
  hochgeladen_am timestamptz default now(),
  erfasst_von  uuid not null references mitarbeiter(id),
  geo          point                    -- optional, nur mit Einwilligung
);
```

Zwei Zeitstempel: `erfasst_am` kommt vom Gerät (kann Tage zurückliegen),
`hochgeladen_am` vom Server. Für die Doku zählt der erste, für die Nachvollziehbarkeit der zweite.

**Die ID kommt vom Client.** Das macht den Upload idempotent — ein
doppelt gesendeter Queue-Eintrag erzeugt keinen zweiten Datensatz.

> GAEB DA XML 3.3 (Stand 2023-01) erlaubt in Phase **X31 Mengenermittlung**
> eingebettete Bilder und PDFs in Base64. Das ist der standardkonforme Weg,
> Baustellenfotos an ein VOB-Aufmaß zu koppeln — vorgesehen für Phase 3.
