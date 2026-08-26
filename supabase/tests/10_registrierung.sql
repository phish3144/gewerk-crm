-- Registrierung, Betriebsgründung und Mitgliedschaft.
--
-- Der Weg, auf dem ein Konto entsteht, war bis 0019 nicht vorhanden: `betrieb`
-- hatte seit 0013 keine INSERT-Policy mehr, `benutzer_betrieb` ist für die
-- Anwendungsrolle nur lesbar. Diese Datei prüft, dass der neue Weg trägt — und
-- dass er nur in die vorgesehene Richtung trägt.
--
-- Gespielt wird mit zwei Konten: Anna gründet, Bruno wird aufgenommen.

\set ON_ERROR_STOP on

-- Die auth-Konten. In Supabase legt GoTrue sie an; lokal genügen die GUCs, aus
-- denen auth.uid() und auth.jwt() lesen.
\set anna  '''a0000000-0000-0000-0000-0000000000aa'''
\set bruno '''b0000000-0000-0000-0000-0000000000bb'''
\set fremd '''f0000000-0000-0000-0000-0000000000ff'''

-- ------------------------------------------------------- 1: ohne Anmeldung ---
set role authenticated;
select set_config('request.jwt.claims', '', false);

do $$
begin
  begin
    perform konto_anlegen('Niemand');
    raise exception 'FAIL konto_anlegen ohne Anmeldung war erlaubt';
  exception when insufficient_privilege then null;
  end;

  begin
    perform betrieb_gruenden('Betrieb ohne Konto');
    raise exception 'FAIL betrieb_gruenden ohne Anmeldung war erlaubt';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---------------------------------------------------- 2: Anna registriert -----
select set_config('request.jwt.claims',
  json_build_object('sub', :anna, 'email', 'anna@beispiel.de')::text, false);

do $$
declare v_id uuid; v_anzahl integer;
begin
  v_id := konto_anlegen('Anna Baumeister');
  if v_id <> 'a0000000-0000-0000-0000-0000000000aa' then
    raise exception 'FAIL konto_anlegen gab % zurueck', v_id;
  end if;

  -- Zweiter Aufruf darf keinen zweiten Datensatz erzeugen: die Anwendung ruft
  -- die Funktion bei jeder Anmeldung auf.
  perform konto_anlegen('Anna Baumeister');
  select count(*) into v_anzahl from benutzer where id = v_id;
  if v_anzahl <> 1 then
    raise exception 'FAIL konto_anlegen ist nicht idempotent: % Zeilen', v_anzahl;
  end if;
end $$;

-- Die E-Mail stammt aus dem Token, nicht aus einem Parameter — sonst koennte
-- sich jeder eine fremde Adresse eintragen und waere ueber mitglied_aufnehmen
-- in einem fremden Betrieb.
do $$
declare v_email text;
begin
  select email into v_email from benutzer where id = 'a0000000-0000-0000-0000-0000000000aa';
  if v_email <> 'anna@beispiel.de' then
    raise exception 'FAIL E-Mail kommt nicht aus dem Token: %', v_email;
  end if;
end $$;

-- --------------------------------------------------- 3: Anna gruendet ---------
do $$
declare v_betrieb uuid; v_rolle betriebsrolle; v_mitarbeiter integer;
begin
  v_betrieb := betrieb_gruenden('Baumeister GmbH');

  select rolle into v_rolle from benutzer_betrieb
   where benutzer_id = 'a0000000-0000-0000-0000-0000000000aa' and betrieb_id = v_betrieb;
  if v_rolle is distinct from 'inhaber' then
    raise exception 'FAIL Gruenderin ist nicht Inhaberin, sondern %', v_rolle;
  end if;

  -- Ohne Mitarbeiterdatensatz kann sie keine Zeit erfassen: zeiteintrag zeigt
  -- auf mitarbeiter, nicht auf benutzer.
  select count(*) into v_mitarbeiter from mitarbeiter
   where betrieb_id = v_betrieb and benutzer_id = 'a0000000-0000-0000-0000-0000000000aa';
  if v_mitarbeiter <> 1 then
    raise exception 'FAIL Gruenderin hat % Mitarbeiterdatensaetze statt 1', v_mitarbeiter;
  end if;

  -- Und sie muss ihren Betrieb durch RLS auch sehen.
  if not exists (select 1 from betrieb where id = v_betrieb) then
    raise exception 'FAIL Gruenderin sieht ihren eigenen Betrieb nicht';
  end if;
end $$;

-- Ohne benutzer-Zeile kein Betrieb: die Reihenfolge ist erzwungen.
select set_config('request.jwt.claims',
  json_build_object('sub', :fremd, 'email', 'fremd@beispiel.de')::text, false);
do $$
begin
  begin
    perform betrieb_gruenden('Betrieb ohne benutzer-Zeile');
    raise exception 'FAIL betrieb_gruenden ohne vorheriges konto_anlegen war erlaubt';
  exception when foreign_key_violation then null;
  end;
end $$;

-- -------------------------------------------------- 4: Bruno registriert ------
select set_config('request.jwt.claims',
  json_build_object('sub', :bruno, 'email', 'bruno@beispiel.de')::text, false);
select konto_anlegen('Bruno Bohrer');

-- Bruno gehoert noch nirgends hin und sieht folglich nichts.
do $$
declare n integer;
begin
  select count(*) into n from betrieb;
  if n <> 0 then
    raise exception 'FAIL Bruno sieht % Betriebe, obwohl er zu keinem gehoert', n;
  end if;
end $$;

-- Und er kann sich nicht selbst aufnehmen.
do $$
declare v_betrieb uuid;
begin
  select id into v_betrieb from betrieb where name = 'Baumeister GmbH';
  -- Bruno kennt die ID nicht ueber RLS, aber ein Angreifer koennte sie raten.
  -- Deshalb hier bewusst mit der echten ID, die wir als postgres holen.
  if v_betrieb is not null then
    raise exception 'FAIL Bruno kann den fremden Betrieb lesen';
  end if;
end $$;

-- Die ID als Sitzungsparameter ablegen. psql ersetzt seine eigenen Variablen
-- nicht innerhalb von $$-Bloecken, current_setting() liest dort aber sauber.
reset role;
select set_config('test.baumeister', id::text, false) from betrieb where name = 'Baumeister GmbH';
set role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :bruno, 'email', 'bruno@beispiel.de')::text, false);

do $$
declare v_betrieb uuid := current_setting('test.baumeister')::uuid;
begin
  begin
    perform mitglied_aufnehmen(v_betrieb, 'bruno@beispiel.de', 'inhaber');
    raise exception 'FAIL Bruno konnte sich selbst in einen fremden Betrieb aufnehmen';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------------- 5: Anna nimmt Bruno auf ----
select set_config('request.jwt.claims',
  json_build_object('sub', :anna, 'email', 'anna@beispiel.de')::text, false);

do $$
declare
  v_betrieb uuid := current_setting('test.baumeister')::uuid;
  v_rolle   betriebsrolle;
  v_satz    numeric;
begin
  perform mitglied_aufnehmen(v_betrieb, 'bruno@beispiel.de', 'monteur', 52.50);

  select bb.rolle, m.stundensatz into v_rolle, v_satz
    from benutzer_betrieb bb
    join mitarbeiter m on m.betrieb_id = bb.betrieb_id and m.benutzer_id = bb.benutzer_id
   where bb.betrieb_id = v_betrieb and bb.benutzer_id = 'b0000000-0000-0000-0000-0000000000bb';

  if v_rolle is distinct from 'monteur' then
    raise exception 'FAIL Bruno hat Rolle % statt monteur', v_rolle;
  end if;
  if v_satz <> 52.50 then
    raise exception 'FAIL Stundensatz ist % statt 52.50', v_satz;
  end if;

  -- Unbekannte Adresse: verstaendlicher Abbruch statt stiller Wirkungslosigkeit.
  begin
    perform mitglied_aufnehmen(v_betrieb, 'niemand@beispiel.de', 'monteur');
    raise exception 'FAIL Aufnahme einer unbekannten Adresse war erfolgreich';
  exception when no_data_found then null;
  end;
end $$;

-- Erneute Aufnahme aendert nur die Rolle und erzeugt keinen zweiten
-- Mitarbeiterdatensatz — sonst haengen die bisherigen Zeiten am falschen.
do $$
declare v_betrieb uuid := current_setting('test.baumeister')::uuid; n integer; v_rolle betriebsrolle;
begin
  perform mitglied_aufnehmen(v_betrieb, 'bruno@beispiel.de', 'buero');

  select count(*) into n from mitarbeiter
   where betrieb_id = v_betrieb and benutzer_id = 'b0000000-0000-0000-0000-0000000000bb';
  if n <> 1 then
    raise exception 'FAIL erneute Aufnahme erzeugte % Mitarbeiterdatensaetze', n;
  end if;

  select rolle into v_rolle from benutzer_betrieb
   where betrieb_id = v_betrieb and benutzer_id = 'b0000000-0000-0000-0000-0000000000bb';
  if v_rolle is distinct from 'buero' then
    raise exception 'FAIL Rolle wurde nicht auf buero gesetzt, sondern %', v_rolle;
  end if;
end $$;

-- ------------------------------------------------ 6: der letzte Inhaber -------
-- Ohne diese Sperre entsteht ein Betrieb, den niemand mehr verwalten und
-- niemand mehr loeschen kann: betrieb_loeschen() verlangt die Inhaberrolle.
do $$
declare v_betrieb uuid := current_setting('test.baumeister')::uuid;
begin
  begin
    perform mitglied_rolle_setzen(v_betrieb, 'a0000000-0000-0000-0000-0000000000aa', 'buero');
    raise exception 'FAIL die letzte Inhaberin konnte ihre Rolle abgeben';
  exception when restrict_violation then null;
  end;

  begin
    perform mitglied_entfernen(v_betrieb, 'a0000000-0000-0000-0000-0000000000aa');
    raise exception 'FAIL die letzte Inhaberin konnte sich selbst entfernen';
  exception when restrict_violation then null;
  end;
end $$;

-- Mit einem zweiten Inhaber geht beides.
do $$
declare v_betrieb uuid := current_setting('test.baumeister')::uuid; v_rolle betriebsrolle;
begin
  perform mitglied_rolle_setzen(v_betrieb, 'b0000000-0000-0000-0000-0000000000bb', 'inhaber');
  perform mitglied_rolle_setzen(v_betrieb, 'a0000000-0000-0000-0000-0000000000aa', 'buero');

  select rolle into v_rolle from benutzer_betrieb
   where betrieb_id = v_betrieb and benutzer_id = 'a0000000-0000-0000-0000-0000000000aa';
  if v_rolle is distinct from 'buero' then
    raise exception 'FAIL Rollenwechsel mit zweitem Inhaber schlug fehl: %', v_rolle;
  end if;
end $$;

-- ------------------------------------------- 7: Entfernen laesst Spuren -------
-- Der Mitarbeiterdatensatz bleibt und wird stillgelegt. An ihm haengen
-- Zeiteintraege; zeiteintrag.mitarbeiter_id traegt `on delete restrict`.
select set_config('request.jwt.claims',
  json_build_object('sub', :bruno, 'email', 'bruno@beispiel.de')::text, false);

do $$
declare v_betrieb uuid := current_setting('test.baumeister')::uuid; v_aktiv boolean; v_benutzer uuid; n integer;
begin
  perform mitglied_entfernen(v_betrieb, 'a0000000-0000-0000-0000-0000000000aa');

  select count(*) into n from benutzer_betrieb
   where betrieb_id = v_betrieb and benutzer_id = 'a0000000-0000-0000-0000-0000000000aa';
  if n <> 0 then
    raise exception 'FAIL Zugehoerigkeit besteht nach dem Entfernen weiter';
  end if;

  select aktiv, benutzer_id into v_aktiv, v_benutzer from mitarbeiter
   where betrieb_id = v_betrieb and name = 'Anna Baumeister';
  if v_aktiv is distinct from false or v_benutzer is not null then
    raise exception 'FAIL Mitarbeiterdatensatz wurde nicht stillgelegt (aktiv=%, benutzer=%)',
      v_aktiv, v_benutzer;
  end if;
end $$;

-- Anna sieht den Betrieb jetzt nicht mehr.
select set_config('request.jwt.claims',
  json_build_object('sub', :anna, 'email', 'anna@beispiel.de')::text, false);
do $$
declare n integer;
begin
  select count(*) into n from betrieb;
  if n <> 0 then
    raise exception 'FAIL Anna sieht nach dem Entfernen noch % Betriebe', n;
  end if;
end $$;

-- ---------------------------------------------------------- aufraeumen --------
select set_config('request.jwt.claims',
  json_build_object('sub', :bruno, 'email', 'bruno@beispiel.de')::text, false);
select betrieb_loeschen(current_setting('test.baumeister')::uuid);
reset role;
delete from benutzer where id in ('a0000000-0000-0000-0000-0000000000aa',
                                  'b0000000-0000-0000-0000-0000000000bb');

\echo '  OK  Registrierung: Konto, Gruendung, Aufnahme, Rollen, letzter Inhaber'
