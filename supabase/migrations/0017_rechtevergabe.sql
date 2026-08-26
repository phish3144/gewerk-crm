-- Rechtevergabe: was die Policies nicht abfangen koennen.
--
-- Bis hierher hat jede Migration an Policies und Triggern gearbeitet und dabei
-- stillschweigend angenommen, die Rollen anon und authenticated haetten genau
-- die Tabellenrechte, die 0006 ihnen erteilt hat. Das stimmt auf einem echten
-- Supabase-Projekt nicht. Supabase setzt im Schema public
--
--   alter default privileges in schema public
--     grant all on tables    to anon, authenticated, service_role;
--   alter default privileges in schema public
--     grant all on functions to anon, authenticated, service_role;
--
-- erteilt von der Rolle postgres - derselben Rolle, unter der die Migrationen
-- laufen. Jede mit "create table" angelegte Tabelle bekommt dadurch sofort ALLE
-- Rechte fuer anon und authenticated, jede neue Funktion sofort EXECUTE. Die
-- Zeile "grant select, insert, update, delete ... to authenticated" aus 0006 hat
-- also nie etwas hinzugefuegt, sie war schon uebererfuellt. Und ein
-- "revoke ... from public" nimmt einer Rolle nichts weg, die das Recht direkt
-- besitzt statt ueber PUBLIC.
--
-- Drei Folgen, alle auf dem Projekt nachgewiesen:
--
--   * anon besass arwdDxtm auf allen 20 Tabellen, auch auf journal und
--     nummernkreis. Getragen hat allein RLS - eine einzige Policy mehr, die
--     "to public" statt "to authenticated" schreibt, und die Daten liegen unter
--     dem oeffentlichen anon-Schluessel offen.
--
--   * authenticated besass TRUNCATE. TRUNCATE unterliegt keiner Zeilenpolicy und
--     feuert keinen Zeilentrigger. Lokal reproduziert: eine Nutzerin, die genau
--     einen Beleg sehen darf, loescht per DELETE erwartungsgemaess nur diesen
--     einen - und raeumt anschliessend mit einem TRUNCATE die Belege ALLER
--     Mandanten ab, samt Kaskade auf beleg_position, zahlung, beleg_anrechnung,
--     einbehalt_position und zeiteintrag. Festgeschriebene Rechnungen
--     eingeschlossen: der Unveraenderlichkeits-Trigger ist ein Zeilentrigger und
--     sieht TRUNCATE nie.
--
--   * naechste_nummer war fuer anon und authenticated direkt aufrufbar. 0009
--     hatte das Recht nur PUBLIC entzogen, das Standardrecht der Rolle blieb.
--     Die Funktion ist security definer und prueft keine Zugehoerigkeit, weil
--     sie das nicht muss - erreichbar sein sollte sie nur ueber
--     beleg_festschreiben. Direkt aufgerufen verbrennt jeder Aufruf eine Nummer
--     im Kreis eines beliebigen fremden Betriebs und reisst genau die Luecke in
--     die Nummernfolge, gegen die der ganze Aufbau anschreibt.
--
-- Diese Migration dreht die Vergabe um: nichts ueber Standardrechte, alles
-- ausdruecklich. supabase/tests/09_rechtevergabe.sql haelt den Zustand fest.

-- ------------------------------------------------------------------- 1 -------
-- Kuenftige Objekte erben keine Rechte mehr. Ab hier muss jede Migration, die
-- eine Tabelle oder Funktion anlegt, die Rechte selbst erteilen. Eine vergessene
-- Zeile faellt dann beim ersten Zugriff auf, statt eine offene Tabelle zu
-- hinterlassen.
--
-- Wirkt nur auf Objekte, die postgres anlegt - genau die aus diesen Migrationen.
-- Der zweite Satz Standardrechte in pg_default_acl stammt von supabase_admin und
-- betrifft die Plattformschemata, nicht public-Objekte aus unseren Migrationen.
alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

-- ------------------------------------------------------------------- 2 -------
-- anon hat in dieser Anwendung keine Aufgabe. Es gibt keine oeffentliche
-- Ansicht, kein Formular ohne Anmeldung, keinen Lesezugriff fuer Gaeste. Also
-- bekommt anon auch kein Recht auf ein einziges Objekt.
--
-- Das Schema-usage bleibt bestehen: PostgREST verbindet unangemeldete Anfragen
-- als anon, und ohne usage scheitern sie mit einer Meldung ueber das Schema
-- statt ueber die Tabelle. Sichtbar wird dadurch nichts - ohne Objektrecht ist
-- kein Objekt erreichbar.
revoke all on all tables    in schema public from anon;
revoke all on all functions in schema public from anon;
revoke all on all sequences in schema public from anon;

-- ------------------------------------------------------------------- 3 -------
-- authenticated behaelt genau die vier Datenrechte, die die Policies dann
-- zeilenweise einschraenken. Alles darueber hinaus faellt weg:
--
--   TRUNCATE (D)   umgeht Policies und Zeilentrigger - siehe oben.
--   REFERENCES (x) erlaubt Fremdschluessel auf fremde Tabellen. Ein solcher
--                  Schluessel laesst sich als Orakel benutzen: der Verstoss
--                  verraet, ob ein Wert existiert, ganz ohne Leserecht.
--   TRIGGER (t)    erlaubt eigene Trigger auf unseren Tabellen. Ein Trigger
--                  laeuft im Kontext der schreibenden Anweisung und koennte
--                  Zeilen abgreifen, die die Policy nie herausgeben wuerde.
--   MAINTAIN (m)   erlaubt VACUUM, ANALYZE, REFRESH und REINDEX auf fremden
--                  Tabellen. Kein Datenleck, aber auch kein Grund.
revoke truncate, references, trigger on all tables in schema public from authenticated;

-- MAINTAIN gibt es erst ab Postgres 17. Das Projekt laeuft auf 17.6, der lokale
-- Testcluster auf 16 - dort ist das Recht kein Begriff und die Zeile ein
-- Syntaxfehler. Deshalb versionsabhaengig, damit dieselbe Datei auf beiden
-- laeuft.
do $$
begin
  if current_setting('server_version_num')::integer >= 170000 then
    execute 'revoke maintain on all tables in schema public from authenticated';
  end if;
end $$;

-- journal wird ausschliesslich vom Trigger journal_schreiben() gefuellt, und der
-- laeuft als security definer unter postgres. Die Anwendungsrolle braucht darauf
-- kein Schreibrecht - bisher hatte sie INSERT, UPDATE und DELETE und wurde
-- allein vom Anfuegen-Trigger aus 0011 aufgehalten. Jetzt liegt schon das Recht
-- nicht mehr vor. Das Leserecht bleibt die Spaltenauswahl aus 0015.
revoke insert, update, delete on journal from authenticated;

-- ------------------------------------------------------------------- 4 -------
-- Ausfuehrungsrechte ebenso: erst alles entziehen, dann die Freigabeliste.
--
-- Der Entzug bei anon und authenticated allein genuegt hier nicht. Der
-- Postgres-Standard fuer Funktionen ist EXECUTE fuer PUBLIC, und PUBLIC schliesst
-- jede Rolle ein - auch anon. Solange dieser Eintrag steht, ist die Funktion
-- ueber die Mitgliedschaft in PUBLIC weiterhin erreichbar, ganz gleich was der
-- Rolle direkt entzogen wurde. Sichtbar wird das im ACL als fuehrendes "=X/postgres"
-- ohne Rollennamen davor. Erst dieser Entzug macht die Freigabeliste zur Liste.
revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public;

-- Zugehoerigkeit lesen - Grundlage jeder Policy, vom Client abfragbar.
grant execute on function meine_betriebe()            to authenticated;
grant execute on function meine_betriebe_schreibend() to authenticated;
grant execute on function meine_betriebe_inhaber()    to authenticated;

-- Fachliche Einstiegspunkte. beleg_festschreiben und betrieb_loeschen sind
-- security definer und pruefen die Zugehoerigkeit jeweils selbst gegen
-- auth.uid(); beleg_summen_neu laeuft als Aufrufer und damit unter RLS.
grant execute on function beleg_festschreiben(uuid) to authenticated;
grant execute on function beleg_summen_neu(uuid)    to authenticated;
grant execute on function betrieb_loeschen(uuid)    to authenticated;

-- Reine Anzeigehilfe ohne Datenzugriff.
grant execute on function nummer_praefix(beleg_art) to authenticated;

-- Und eine Freigabe, die nicht die Anwendung braucht, sondern die Datenbank
-- selbst: beleg_nicht_loeschbar() und journal_ist_anfuegend() sind Trigger ohne
-- security definer und laufen damit im Kontext der schreibenden Rolle. Ihr
-- Aufruf von loeschung_laeuft_fuer() wird gegen deren Rechte geprueft. Ohne
-- diese Zeile scheitert jedes zulaessige DELETE auf beleg an einem Recht, das
-- der Nutzerin gar nicht bewusst fehlt.
--
-- Die Freigabe kostet nichts: die Funktion ist auf current_user = 'postgres'
-- verriegelt und liefert jeder Anwendungsrolle immer false. Als RPC-Endpunkt
-- gibt sie eine Konstante zurueck. Sie hier security definer zu machen waere der
-- Fehler - dann waere current_user innerhalb der Funktion postgres, und die
-- Verriegelung des Loeschpfads waere aufgehoben.
grant execute on function loeschung_laeuft_fuer(uuid) to authenticated;

-- Nicht in der Liste und das mit Absicht:
--
--   naechste_nummer   nur ueber beleg_festschreiben erreichbar. Eine zweite
--                     Zugehoerigkeitspruefung in der Funktion selbst waere toter
--                     Code - der einzige Aufrufer prueft bereits, und ein
--                     direkter Aufruf ist ab hier kein zulaessiger Weg mehr.
--   journal_schreiben  security definer, gehoert nur an den Trigger.
--   alle Triggerfunktionen  Postgres prueft das Ausfuehrungsrecht beim Anlegen
--                     des Triggers, nicht beim Ausloesen. Der Entzug haelt sie
--                     als RPC-Endpunkt zu, ohne die Trigger zu beruehren.

-- ------------------------------------------------------------------- 5 -------
-- Fehlender search_path (Supabase-Lint 0011). Die Funktion ist immutable und
-- fasst nur ihr Argument an, steht aber im Aufrufpfad von naechste_nummer.
-- Festgesetzt, damit die Kette lueckenlos ist.
create or replace function nummer_praefix(p_art beleg_art)
  returns text
  language sql
  immutable
  set search_path = public, pg_temp
  as $$
    select case p_art
      when 'angebot'           then 'AN-'
      when 'auftrag'           then 'AU-'
      when 'abschlagsrechnung' then 'AR-'
      when 'teilrechnung'      then 'TR-'
      when 'schlussrechnung'   then 'RE-'
      when 'gutschrift'        then 'GU-'
      when 'storno'            then 'ST-'
    end
  $$;

-- create or replace setzt die Rechte zurueck auf den Standard, der oben gerade
-- entzogen wurde. Deshalb hier noch einmal, nach der Neuanlage.
revoke all on function nummer_praefix(beleg_art) from public, anon, authenticated;
grant execute on function nummer_praefix(beleg_art) to authenticated;
