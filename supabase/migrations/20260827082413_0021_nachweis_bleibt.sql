-- Der Nachweis bleibt, solange eine Buchung ihn braucht.
--
-- Befund aus dem Nachlauf zu 0020, am lebenden Objekt reproduziert:
--
--   delete from dokumentation where id = '...';
--   ERROR: new row for relation "zeiteintrag" violates check constraint
--          "zeit_ohne_position_braucht_nachweis"
--
-- Die Daten blieben dabei richtig - geloescht wurde nichts, die Buchung behielt
-- ihren Nachweis. Aber die Meldung nennt die falsche Tabelle: wer eine Notiz
-- loeschen will, liest etwas ueber eine Pruefregel auf den Zeiteintraegen und
-- sucht den Fehler an der falschen Stelle.
--
-- Ursache ist ON DELETE SET NULL: Postgres versucht den Verweis zu leeren, und
-- erst die Pruefregel faengt das ab. RESTRICT sagt stattdessen genau das, was
-- gemeint ist - "wird noch verwendet" - und nennt dabei die verweisende
-- Tabelle. Dasselbe Muster wie bei mitarbeiter: was als Beleg dient, wird nicht
-- weggeraeumt, solange etwas daran haengt.

alter table zeiteintrag drop constraint zeiteintrag_nachweis_fk;
alter table zeiteintrag add  constraint zeiteintrag_nachweis_fk
  foreign key (betrieb_id, nachweis_id) references dokumentation (betrieb_id, id)
  on delete restrict;

alter table materialentnahme drop constraint materialentnahme_nachweis_fk;
alter table materialentnahme add  constraint materialentnahme_nachweis_fk
  foreign key (betrieb_id, nachweis_id) references dokumentation (betrieb_id, id)
  on delete restrict;
