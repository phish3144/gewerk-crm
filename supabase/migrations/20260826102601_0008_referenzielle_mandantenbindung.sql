-- Der schwerste Befund der adversarialen Pruefung, reproduziert:
--
--   Anna (Betrieb A) fuegt eine Position in eine festgeschriebene Rechnung von
--   Betrieb B ein. Die Policy prueft nur beleg_position.betrieb_id = A und laesst
--   die Zeile durch. Bruno sieht sie nicht und kann sie nicht loeschen, aber jeder
--   Export auf Eigentuemerebene - GoBD-Datenexport, DATEV, Backup - liefert sie aus.
--
-- Ursache: kein einziger Fremdschluessel traegt eine Mandantenkomponente. Und
-- Postgres fuehrt Fremdschluessel-Pruefungen als Tabelleneigentuemer ohne RLS aus -
-- die Existenzpruefung sieht also ALLE Mandanten. Eine Policy kann das prinzipiell
-- nicht heilen.
--
-- Die Loesung ist strukturell statt regelbasiert: jede mandantengebundene Tabelle
-- bekommt einen Schluesselkandidaten (betrieb_id, id), und jeder Fremdschluessel
-- verweist auf dieses Paar. Ein mandantenuebergreifender Verweis ist damit nicht
-- mehr verboten, sondern nicht mehr formulierbar.

-- ------------------------------------------- Schluesselkandidaten der Eltern --
alter table kunde          add constraint kunde_mandant_id          unique (betrieb_id, id);
alter table projekt        add constraint projekt_mandant_id        unique (betrieb_id, id);
alter table mitarbeiter    add constraint mitarbeiter_mandant_id    unique (betrieb_id, id);
alter table lieferant      add constraint lieferant_mandant_id      unique (betrieb_id, id);
alter table artikel        add constraint artikel_mandant_id        unique (betrieb_id, id);
alter table beleg          add constraint beleg_mandant_id          unique (betrieb_id, id);
alter table beleg_position add constraint beleg_position_mandant_id unique (betrieb_id, id);

-- --------------------------------------------- Fremdschluessel neu verdrahten --
-- ON DELETE SET NULL braucht eine Spaltenliste, sonst versuchte Postgres auch
-- betrieb_id auf NULL zu setzen - die Spalte ist NOT NULL. Erst ab Postgres 15
-- moeglich; Supabase laeuft auf 17.

alter table ansprechpartner drop constraint ansprechpartner_kunde_id_fkey;
alter table ansprechpartner add  constraint ansprechpartner_kunde_fk
  foreign key (betrieb_id, kunde_id) references kunde (betrieb_id, id) on delete cascade;

alter table artikel drop constraint artikel_lieferant_id_fkey;
alter table artikel add  constraint artikel_lieferant_fk
  foreign key (betrieb_id, lieferant_id) references lieferant (betrieb_id, id)
  on delete set null (lieferant_id);

alter table projekt drop constraint projekt_kunde_id_fkey;
alter table projekt add  constraint projekt_kunde_fk
  foreign key (betrieb_id, kunde_id) references kunde (betrieb_id, id) on delete restrict;

alter table beleg drop constraint beleg_kunde_id_fkey;
alter table beleg add  constraint beleg_kunde_fk
  foreign key (betrieb_id, kunde_id) references kunde (betrieb_id, id) on delete restrict;

alter table beleg drop constraint beleg_projekt_id_fkey;
alter table beleg add  constraint beleg_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id)
  on delete set null (projekt_id);

alter table beleg drop constraint beleg_vorgaenger_id_fkey;
alter table beleg add  constraint beleg_vorgaenger_fk
  foreign key (betrieb_id, vorgaenger_id) references beleg (betrieb_id, id)
  on delete set null (vorgaenger_id);

alter table beleg drop constraint beleg_storniert_durch_fkey;
alter table beleg add  constraint beleg_storniert_durch_fk
  foreign key (betrieb_id, storniert_durch) references beleg (betrieb_id, id)
  on delete set null (storniert_durch);

alter table beleg_position drop constraint beleg_position_beleg_id_fkey;
alter table beleg_position add  constraint beleg_position_beleg_fk
  foreign key (betrieb_id, beleg_id) references beleg (betrieb_id, id) on delete cascade;

alter table beleg_position drop constraint beleg_position_artikel_id_fkey;
alter table beleg_position add  constraint beleg_position_artikel_fk
  foreign key (betrieb_id, artikel_id) references artikel (betrieb_id, id)
  on delete set null (artikel_id);

alter table dokumentation drop constraint dokumentation_projekt_id_fkey;
alter table dokumentation add  constraint dokumentation_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id) on delete cascade;

alter table dokumentation drop constraint dokumentation_erfasst_von_fkey;
alter table dokumentation add  constraint dokumentation_erfasst_von_fk
  foreign key (betrieb_id, erfasst_von) references mitarbeiter (betrieb_id, id) on delete restrict;

alter table zeiteintrag drop constraint zeiteintrag_projekt_id_fkey;
alter table zeiteintrag add  constraint zeiteintrag_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id)
  on delete set null (projekt_id);

alter table zeiteintrag drop constraint zeiteintrag_mitarbeiter_id_fkey;
alter table zeiteintrag add  constraint zeiteintrag_mitarbeiter_fk
  foreign key (betrieb_id, mitarbeiter_id) references mitarbeiter (betrieb_id, id) on delete restrict;

alter table zeiteintrag drop constraint zeiteintrag_position_id_fkey;
alter table zeiteintrag add  constraint zeiteintrag_position_fk
  foreign key (betrieb_id, position_id) references beleg_position (betrieb_id, id)
  on delete set null (position_id);

alter table einsatz drop constraint einsatz_projekt_id_fkey;
alter table einsatz add  constraint einsatz_projekt_fk
  foreign key (betrieb_id, projekt_id) references projekt (betrieb_id, id) on delete cascade;

alter table einsatz drop constraint einsatz_mitarbeiter_id_fkey;
alter table einsatz add  constraint einsatz_mitarbeiter_fk
  foreign key (betrieb_id, mitarbeiter_id) references mitarbeiter (betrieb_id, id) on delete cascade;

alter table einsatz drop constraint einsatz_subunternehmer_id_fkey;
alter table einsatz add  constraint einsatz_subunternehmer_fk
  foreign key (betrieb_id, subunternehmer_id) references lieferant (betrieb_id, id) on delete cascade;

-- ------------------------------------- Eindeutigkeit mandantenweise schneiden --
-- unique (beleg_id, position_nr) war ein Existenzorakel: die Verletzung verriet,
-- dass ein fremder Beleg mit dieser Positionsnummer existiert.
alter table beleg_position drop constraint beleg_position_beleg_id_position_nr_key;
alter table beleg_position add  constraint beleg_position_nr_eindeutig
  unique (betrieb_id, beleg_id, position_nr);

-- Der Ausschluss-Constraint verglich Mitarbeiter ueber Mandantengrenzen hinweg.
-- Zwar kann ein Mitarbeiter nur zu einem Betrieb gehoeren, aber die Bedingung
-- gehoert trotzdem auf den Mandanten geschnitten - sonst sperrt eine Zeile aus
-- Betrieb B eine Einplanung in Betrieb A und verraet dabei fremde Einsatzzeiten.
alter table einsatz drop constraint einsatz_mitarbeiter_ohne_ueberschneidung;
alter table einsatz add  constraint einsatz_mitarbeiter_ohne_ueberschneidung
  exclude using gist (
    betrieb_id     with =,
    mitarbeiter_id with =,
    tstzrange(von, bis) with &&
  ) where (ressource_art = 'mitarbeiter');
