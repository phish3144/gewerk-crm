-- Abschlagszahlungen, Absetzung in der Schlussrechnung und Reverse Charge.
-- Grundlage: docs/rechnungsmodell.md, jede Regel dort an einen Paragrafen
-- oder amtlichen Erlasstext gebunden.
--
-- Die tragende Einsicht: Der Steuerentstehungszeitpunkt haengt an der
-- VEREINNAHMUNG, nicht am Belegdatum (§ 13 Abs. 1 Nr. 1 Buchst. a Satz 4 UStG).
-- Deshalb ist die Zahlung eine eigene Ebene und keine Spalte am Beleg.

create type rc_status as enum ('kein_rc', 'rc_13b_nr4');
create type zahlungsart as enum ('abschlag', 'teilzahlung', 'schlusszahlung', 'vorauszahlung');

-- ------------------------------------------------------------- zahlung -----
create table zahlung (
  id           uuid primary key default gen_random_uuid(),
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  beleg_id     uuid not null,
  -- UStAE 13.6 Abs. 1 Satz 3: verbindlich das GUTSCHRIFTSDATUM des Bankkontos.
  -- Nicht die Wertstellung, nicht der Ueberweisungsauftrag, nicht das
  -- Buchungsdatum im CRM.
  vereinnahmt_am date not null,
  betrag_brutto  numeric(14,2) not null,
  entgelt_netto  numeric(14,2) not null,
  steuersatz     numeric(5,2)  not null,
  steuerbetrag   numeric(14,2) not null,
  -- § 13b Abs. 4 Satz 2 UStG: der Status gilt je Vereinnahmung, nicht je Beleg.
  status_rc      rc_status not null default 'kein_rc',
  -- § 16 Abs. 3 Nr. 1 Satz 5 VOB/B: eine Teilzahlung auf eine Schlussrechnung kann
  -- eine Abschlagszahlung sein - unabhaengig von der Belegart des Zielbelegs.
  art            zahlungsart not null,
  -- UStAE 14.5 Abs. 19 Satz 7: Skonto lebt hier, niemals am Beleg.
  skonto_brutto           numeric(14,2) not null default 0,
  entgeltminderung_netto  numeric(14,2) not null default 0,
  ust_korrekturbetrag     numeric(14,2) not null default 0,
  -- § 16 Abs. 5 Nr. 2 VOB/B: eine einseitige unberechtigte Kuerzung ist KEINE
  -- Entgeltminderung und darf die Umsatzsteuer nicht beruehren.
  skonto_berechtigt boolean not null default true,
  bemerkung    text,
  erfasst_am   timestamptz not null default now(),

  -- § 14a Abs. 5 Satz 2 UStG: bei Steuerschuldnerschaft des Leistungsempfaengers
  -- wird keine Steuer ausgewiesen.
  constraint zahlung_rc_ohne_steuer check (status_rc = 'kein_rc' or (steuerbetrag = 0 and steuersatz = 0)),
  constraint zahlung_betraege_stimmig check (betrag_brutto = entgelt_netto + steuerbetrag),
  constraint zahlung_nicht_negativ check (betrag_brutto >= 0 and skonto_brutto >= 0),
  constraint zahlung_mandant_id unique (betrieb_id, id)
);
alter table zahlung add constraint zahlung_beleg_fk
  foreign key (betrieb_id, beleg_id) references beleg (betrieb_id, id) on delete cascade;
create index on zahlung (betrieb_id);
create index on zahlung (betrieb_id, vereinnahmt_am);
create index on zahlung (beleg_id);

comment on table zahlung is
  'Steuerbemessungsebene. Ein Beleg hat 0..n Zahlungen, nicht 1:1 (UStAE 14.8 Abs. 5 Saetze 3-4). '
  'Der Unveraenderlichkeits-Trigger fuer festgeschriebene Belege wird bewusst NICHT hierher '
  'ausgeweitet - sonst waere Skonto nicht buchbar (UStAE 14.5 Abs. 19 Satz 7).';

-- --------------------------------------------------- beleg_anrechnung ------
-- § 14 Abs. 5 Satz 2 UStG: In der Endrechnung sind die vereinnahmten Teilentgelte
-- UND die darauf entfallenden Steuerbetraege abzusetzen. Wer das unterlaesst,
-- schuldet die Steuer auf die Anzahlungen zusaetzlich nach § 14c Abs. 1 UStG.
create table beleg_anrechnung (
  id                   uuid primary key default gen_random_uuid(),
  betrieb_id           uuid not null references betrieb(id) on delete cascade,
  schlussrechnung_id   uuid not null,
  abschlagsrechnung_id uuid not null,
  -- Die Norm knuepft an die VEREINNAHMTEN Teilentgelte an, nicht an die blosse
  -- Existenz einer Rechnung. Deshalb haengt die Anrechnung an der Zahlung.
  zahlung_id           uuid not null,
  vereinnahmt_am       date not null,
  -- Je Steuersatz zu fuehren: eine Bruttosumme genuegt der Norm nicht.
  entgelt_netto        numeric(14,2) not null,
  steuersatz           numeric(5,2)  not null,
  steuerbetrag         numeric(14,2) not null,
  angerechnet_brutto   numeric(14,2) not null,
  -- UStAE 13b.12 Abs. 3 Satz 4: der damalige Status bleibt bestehen. Kopieren,
  -- niemals neu rechnen.
  status_rc            rc_status not null,
  -- BT-25 und BT-26 der EN 16931. Denormalisierte Kopie, weil die
  -- festgeschriebene Rechnung den uebermittelten Wert behalten muss.
  vorbeleg_nummer      text not null,
  vorbeleg_datum       date not null,

  constraint anrechnung_rc_ohne_steuer check (status_rc = 'kein_rc' or (steuerbetrag = 0 and steuersatz = 0)),
  constraint anrechnung_betraege_stimmig check (angerechnet_brutto = entgelt_netto + steuerbetrag),
  constraint anrechnung_eindeutig unique (betrieb_id, schlussrechnung_id, zahlung_id),
  constraint anrechnung_mandant_id unique (betrieb_id, id)
);
alter table beleg_anrechnung
  add constraint anrechnung_schlussrechnung_fk
    foreign key (betrieb_id, schlussrechnung_id) references beleg (betrieb_id, id) on delete cascade,
  add constraint anrechnung_abschlagsrechnung_fk
    foreign key (betrieb_id, abschlagsrechnung_id) references beleg (betrieb_id, id) on delete restrict,
  add constraint anrechnung_zahlung_fk
    foreign key (betrieb_id, zahlung_id) references zahlung (betrieb_id, id) on delete restrict;
create index on beleg_anrechnung (betrieb_id);
create index on beleg_anrechnung (schlussrechnung_id);

comment on table beleg_anrechnung is
  'UStAE 14.8 Abs. 9 Satz 1: Ein Storno der Abschlagsrechnung entfernt sie NICHT aus der '
  'Absetzungsbasis. Auswertende Abfragen duerfen kein Filter auf den Belegstatus tragen.';

-- ---------------------------------------------------------- Sicherheiten ---
create type sicherheit_zweck  as enum ('vertragserfuellung', 'maengelansprueche');
create type sicherheit_art    as enum ('einbehalt', 'buergschaft', 'hinterlegung');
create type bemessungsbasis   as enum ('auftragssumme', 'abrechnungssumme');
create type einbehalt_basis   as enum ('brutto', 'netto');

create table sicherheit (
  id           uuid primary key default gen_random_uuid(),
  betrieb_id   uuid not null references betrieb(id) on delete cascade,
  projekt_id   uuid not null,
  zweck        sicherheit_zweck not null,
  art          sicherheit_art   not null,
  -- § 17 Abs. 6 Nr. 1 Satz 1 VOB/B: ZWEI verschiedene Groessen, niemals eine
  -- Spalte. Die Rate ist die hoechstzulaessige Kuerzung JE ZAHLUNG, die
  -- Sicherheitssumme der vertragliche Zielbetrag.
  rate_prozent          numeric(5,2) check (rate_prozent is null or rate_prozent <= 10.00),
  sicherheitssumme_soll numeric(14,2) not null,
  einbehalten_ist       numeric(14,2) not null default 0,
  -- Bewusst OHNE Prozent-Vorgabe: die gaengigen 5 % und 3 % stammen aus der
  -- VOB/A, die nicht auf der Primaerquellenliste stand. Siehe
  -- docs/rechnungsmodell.md Abschnitt 5.
  basis_bemessung bemessungsbasis not null,
  -- § 17 Abs. 6 Nr. 1 Satz 2 VOB/B: bei § 13b UStG bleibt die Umsatzsteuer
  -- unberuecksichtigt, der Einbehalt geht dann vom Netto.
  basis_einbehalt einbehalt_basis not null,
  sperrkonto_iban     text,
  sperrkonto_institut text,
  -- § 17 Abs. 8 Nr. 1 und Nr. 2 VOB/B: je Zweck ein anderer Rueckgabezeitpunkt.
  freigabe_soll       date,
  freigabe_vereinbart date,
  freigegeben_am      date,
  verwertet_betrag    numeric(14,2) not null default 0,

  constraint sicherheit_nicht_ueber_soll check (einbehalten_ist <= sicherheitssumme_soll),
  constraint sicherheit_betraege_nicht_negativ check (
    sicherheitssumme_soll >= 0 and einbehalten_ist >= 0 and verwertet_betrag >= 0
  ),
  constraint sicherheit_mandant_id unique (betrieb_id, id)
);
alter table sicherheit add constraint sicherheit_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id) on delete cascade;
create index on sicherheit (betrieb_id);
create index on sicherheit (projekt_id);

-- § 17 Abs. 8 Nr. 1 VOB/B: die Maengelsicherheit loest die
-- Vertragserfuellungssicherheit ab. Nie zwei aktive Zeilen desselben Zwecks.
create unique index sicherheit_je_zweck_aktiv on sicherheit (betrieb_id, projekt_id, zweck)
  where freigegeben_am is null;

-- Haelt fest, welcher Beleg wie viel beigetragen hat, OHNE die Belegsummen
-- anzufassen. § 10 Abs. 1 Satz 2 UStG: der Einbehalt mindert das Entgelt nicht.
create table einbehalt_position (
  id            uuid primary key default gen_random_uuid(),
  betrieb_id    uuid not null references betrieb(id) on delete cascade,
  beleg_id      uuid not null,
  sicherheit_id uuid not null,
  betrag        numeric(14,2) not null check (betrag >= 0),
  -- § 17 Abs. 8 Nr. 2 VOB/B: eigene Faelligkeit, unabhaengig vom Zahlungsziel
  -- des Belegs.
  faellig_ab    date,
  constraint einbehalt_je_beleg_eindeutig unique (betrieb_id, beleg_id, sicherheit_id),
  constraint einbehalt_mandant_id unique (betrieb_id, id)
);
alter table einbehalt_position
  add constraint einbehalt_beleg_fk
    foreign key (betrieb_id, beleg_id) references beleg (betrieb_id, id) on delete cascade,
  add constraint einbehalt_sicherheit_fk
    foreign key (betrieb_id, sicherheit_id) references sicherheit (betrieb_id, id) on delete cascade;
create index on einbehalt_position (betrieb_id);
create index on einbehalt_position (sicherheit_id);

-- § 17 Abs. 6 Nr. 1 Satz 2 VOB/B: ist der Beleg reverse-charge, waere ein
-- Brutto-Einbehalt rechnerisch falsch - es ist keine Umsatzsteuer ausgewiesen.
create or replace function einbehalt_basis_passt()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare v_basis einbehalt_basis; v_rc boolean;
begin
  select s.basis_einbehalt into v_basis from sicherheit s where s.id = new.sicherheit_id;
  select exists (select 1 from zahlung z where z.beleg_id = new.beleg_id and z.status_rc = 'rc_13b_nr4')
    into v_rc;
  if v_rc and v_basis = 'brutto' then
    raise exception
      'Beleg % ist reverse-charge; ein Brutto-Einbehalt ist nicht moeglich (§ 17 Abs. 6 Nr. 1 Satz 2 VOB/B).',
      new.beleg_id using errcode = 'restrict_violation';
  end if;
  return new;
end $$;

create trigger trg_einbehalt_basis_passt
  before insert or update on einbehalt_position
  for each row execute function einbehalt_basis_passt();

-- ------------------------------------------------------------- Zahlstand ---
-- Der Zahlungsstand ist eine Sicht, keine Spalte am Beleg: Belegstatus und
-- Zahlungsstand sind unabhaengig voneinander.
create view v_beleg_zahlungsstand as
select
  b.id                as beleg_id,
  b.betrieb_id,
  b.nummer,
  b.brutto,
  coalesce(z.gezahlt, 0)     as gezahlt_brutto,
  coalesce(e.einbehalten, 0) as einbehalten,
  -- § 10 Abs. 1 Satz 2 UStG: der Einbehalt mindert die Forderung nicht,
  -- sondern nur den jetzt faelligen Zahlbetrag.
  b.brutto - coalesce(e.einbehalten, 0)                     as zahlbetrag,
  b.brutto - coalesce(e.einbehalten, 0) - coalesce(z.gezahlt, 0) as offen
from beleg b
left join (select beleg_id, sum(betrag_brutto) as gezahlt from zahlung group by beleg_id) z
       on z.beleg_id = b.id
left join (select beleg_id, sum(betrag) as einbehalten from einbehalt_position group by beleg_id) e
       on e.beleg_id = b.id;

-- --------------------------------------------------- § 14c-Falle sperren ---
-- UStAE 14.8 Abs. 10 Saetze 1-3: Werden die vereinnahmten Teilentgelte und die
-- darauf entfallenden Steuerbetraege in der Endrechnung nicht oder nur
-- teilweise abgesetzt, schuldet der Unternehmer den in der Endrechnung
-- ausgewiesenen GESAMTEN Steuerbetrag - und den auf die Anzahlungen
-- entfallenden Teil ZUSAETZLICH nach § 14c Abs. 1 UStG.
--
-- Das ist der teuerste Fehler im ganzen Rechnungsmodell, und er entsteht durch
-- blosses Vergessen. Deshalb blockiert die Datenbank die Festschreibung.
--
-- Als eigener Trigger statt in beleg_festschreiben, damit die Pruefung auch
-- greift, wenn der Status auf anderem Weg gesetzt wird.
create or replace function schlussrechnung_absetzung_vollstaendig()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_fehlend integer;
  v_summe   numeric(14,2);
begin
  if new.art <> 'schlussrechnung' or new.projekt_id is null then
    return new;
  end if;

  -- Jede vereinnahmte Zahlung auf eine Abschlagsrechnung desselben Projekts
  -- muss in dieser Schlussrechnung angerechnet sein. Der Filter kennt bewusst
  -- KEINE Bedingung auf den Belegstatus: ein Storno der Abschlagsrechnung
  -- entfernt sie nicht aus der Absetzungsbasis (UStAE 14.8 Abs. 9 Satz 1).
  select count(*), coalesce(sum(z.betrag_brutto), 0) into v_fehlend, v_summe
    from zahlung z
    join beleg ab on ab.id = z.beleg_id
   where ab.betrieb_id = new.betrieb_id
     and ab.projekt_id = new.projekt_id
     and ab.art in ('abschlagsrechnung', 'teilrechnung')
     and not exists (
       select 1 from beleg_anrechnung a
        where a.schlussrechnung_id = new.id
          and a.zahlung_id = z.id
     );

  if v_fehlend > 0 then
    raise exception
      'Schlussrechnung setzt % vereinnahmte Abschlagszahlung(en) ueber % EUR nicht ab. '
      'Das loest zusaetzliche Steuerschuld nach § 14c Abs. 1 UStG aus (UStAE 14.8 Abs. 10).',
      v_fehlend, v_summe
      using errcode = 'restrict_violation';
  end if;
  return new;
end $$;

create trigger trg_schlussrechnung_absetzung
  before update on beleg
  for each row
  when (old.status = 'entwurf' and new.status <> 'entwurf')
  execute function schlussrechnung_absetzung_vollstaendig();

-- ------------------------------------------------------------ Journal ------
create trigger trg_journal_zahlung
  after insert or update or delete on zahlung
  for each row execute function journal_schreiben();
create trigger trg_journal_anrechnung
  after insert or update or delete on beleg_anrechnung
  for each row execute function journal_schreiben();
create trigger trg_journal_einbehalt
  after insert or update or delete on einbehalt_position
  for each row execute function journal_schreiben();

-- ---------------------------------------------------------------- RLS ------
-- Dasselbe Muster wie in 0013: lesen alle im Betrieb, schreiben Inhaber und
-- Buero. Geld anfassen ist keine Monteursaufgabe.
do $$
declare t text;
begin
  foreach t in array array['zahlung', 'beleg_anrechnung', 'sicherheit', 'einbehalt_position']
  loop
    execute format('alter table %I enable row level security', t);
    execute format($f$
      create policy %I on %I for select to authenticated
        using (betrieb_id = any (array(select meine_betriebe())))
    $f$, t || '_lesen', t);
    execute format($f$
      create policy %I on %I for insert to authenticated
        with check (betrieb_id = any (array(select meine_betriebe_schreibend())))
    $f$, t || '_anlegen', t);
    execute format($f$
      create policy %I on %I for update to authenticated
        using      (betrieb_id = any (array(select meine_betriebe_schreibend())))
        with check (betrieb_id = any (array(select meine_betriebe_schreibend())))
    $f$, t || '_aendern', t);
    execute format($f$
      create policy %I on %I for delete to authenticated
        using (betrieb_id = any (array(select meine_betriebe_schreibend())))
    $f$, t || '_loeschen', t);
    execute format('grant select, insert, update, delete on %I to authenticated', t);
  end loop;
end $$;

-- Die Sicht erbt die Policies ihrer Basistabellen, weil sie mit den Rechten
-- des Aufrufers ausgefuehrt wird.
alter view v_beleg_zahlungsstand set (security_invoker = true);
grant select on v_beleg_zahlungsstand to authenticated;
