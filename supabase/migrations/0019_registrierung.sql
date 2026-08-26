-- Registrierung, Betriebsgründung und Mitgliedschaft.
--
-- Aufgefallen beim Bau der Anmeldemaske: das Schema hat bis hierher keinen Weg,
-- auf dem ein Konto überhaupt entsteht.
--
--   * `betrieb` hat seit 0013 nur noch `betrieb_lesen` (select) und
--     `betrieb_aendern` (update). Die alte Policy `betrieb_eigene` galt `for
--     all` und wurde ersetzt — dabei ist INSERT ersatzlos entfallen. Niemand
--     kann einen Betrieb anlegen, auch kein Inhaber.
--   * `benutzer` und `benutzer_betrieb` sind für die Anwendungsrolle nur
--     lesbar. 0006 merkt dazu an: „Einladungen laufen über eine gesonderte
--     Funktion." Diese Funktion gab es nicht.
--
-- Beides ist richtig so: wer sich selbst in `benutzer_betrieb` eintragen kann,
-- hebelt die gesamte Mandantentrennung aus, und eine INSERT-Policy auf
-- `betrieb` kann die Zugehörigkeit nicht mitprüfen, weil es sie im Moment des
-- Einfügens noch nicht gibt. Der Weg führt deshalb über security-definer-
-- Funktionen, die ihre Vorbedingungen selbst prüfen — dasselbe Muster wie bei
-- `beleg_festschreiben` und `betrieb_loeschen`.
--
-- Vier Einstiegspunkte, jeder mit genau einer Aufgabe:
--
--   konto_anlegen        nach der Registrierung: die eigene benutzer-Zeile
--   betrieb_gruenden     einen neuen Betrieb, der Gründer wird Inhaber
--   mitglied_aufnehmen   Kollegin in den eigenen Betrieb holen
--   mitglied_rolle_setzen / mitglied_entfernen   Verwaltung durch den Inhaber

-- ------------------------------------------------------------------- 1 -------
-- Die eigene benutzer-Zeile. `benutzer` spiegelt auth.users; Supabase legt das
-- Konto dort an, die anwendungseigenen Felder entstehen hier.
--
-- Die E-Mail kommt aus dem Token, nicht aus einem Parameter. Andernfalls könnte
-- sich jeder eine beliebige fremde Adresse eintragen und wäre über
-- mitglied_aufnehmen in einem fremden Betrieb.
--
-- Idempotent: die Anwendung darf die Funktion bei jeder Anmeldung aufrufen,
-- ohne zu wissen, ob die Zeile schon existiert.
create or replace function konto_anlegen(p_anzeigename text)
  returns uuid
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_uid   uuid := (select auth.uid());
  v_email text := (select auth.jwt() ->> 'email');
  v_name  text := btrim(coalesce(p_anzeigename, ''));
begin
  if v_uid is null then
    raise exception 'Kein angemeldetes Konto' using errcode = 'insufficient_privilege';
  end if;
  if v_email is null or btrim(v_email) = '' then
    raise exception 'Das Token enthaelt keine E-Mail-Adresse' using errcode = 'insufficient_privilege';
  end if;
  if v_name = '' then
    raise exception 'Ein Anzeigename wird gebraucht' using errcode = 'check_violation';
  end if;

  insert into benutzer (id, email, anzeigename)
  values (v_uid, v_email, v_name)
  on conflict (id) do update
     set email       = excluded.email,
         anzeigename = excluded.anzeigename;

  return v_uid;
end $$;

-- ------------------------------------------------------------------- 2 -------
-- Einen Betrieb gründen. Der Gründer wird Inhaber und bekommt gleich einen
-- Mitarbeiterdatensatz — ohne den kann er keine Zeit erfassen, weil
-- `zeiteintrag.mitarbeiter_id` darauf zeigt und nicht auf `benutzer`.
--
-- Bewusst keine Obergrenze: jemand kann zwei Betriebe führen, und das Modell
-- trägt Mehrfachzugehörigkeit von Anfang an.
create or replace function betrieb_gruenden(p_name text)
  returns uuid
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_uid     uuid := (select auth.uid());
  v_name    text := btrim(coalesce(p_name, ''));
  v_betrieb uuid;
  v_person  benutzer%rowtype;
begin
  if v_uid is null then
    raise exception 'Kein angemeldetes Konto' using errcode = 'insufficient_privilege';
  end if;
  if v_name = '' then
    raise exception 'Der Betrieb braucht einen Namen' using errcode = 'check_violation';
  end if;

  select * into v_person from benutzer where id = v_uid;
  if not found then
    raise exception 'Zuerst konto_anlegen aufrufen' using errcode = 'foreign_key_violation';
  end if;

  insert into betrieb (name) values (v_name) returning id into v_betrieb;

  insert into benutzer_betrieb (benutzer_id, betrieb_id, rolle)
  values (v_uid, v_betrieb, 'inhaber');

  insert into mitarbeiter (betrieb_id, benutzer_id, name)
  values (v_betrieb, v_uid, v_person.anzeigename);

  return v_betrieb;
end $$;

-- ------------------------------------------------------------------- 3 -------
-- Eine Kollegin aufnehmen. Nur der Inhaber, und nur in den eigenen Betrieb.
--
-- Die Person muss bereits ein Konto haben — eingeladen wird über die
-- E-Mail-Adresse, mit der sie sich registriert hat. Ein Einladungsverfahren mit
-- Token, das auch Personen ohne Konto erreicht, gehört zur Benutzerverwaltung
-- und ist hier bewusst nicht vorweggenommen.
--
-- Bekannter Nebeneffekt: die Fehlermeldung verrät einem Inhaber, ob zu einer
-- Adresse ein Konto besteht. Der Kreis ist auf angemeldete Inhaber begrenzt,
-- und die Alternative — eine nichtssagende Meldung — würde die Aufnahme
-- unbedienbar machen, weil ein Tippfehler nicht mehr von „noch nicht
-- registriert" zu unterscheiden wäre.
--
-- Idempotent: erneutes Aufnehmen setzt nur die Rolle neu.
create or replace function mitglied_aufnehmen(
    p_betrieb     uuid,
    p_email       text,
    p_rolle       betriebsrolle default 'monteur',
    p_stundensatz numeric default 0)
  returns uuid
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_uid    uuid := (select auth.uid());
  v_email  text := lower(btrim(coalesce(p_email, '')));
  v_person benutzer%rowtype;
begin
  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.benutzer_id = v_uid
       and bb.betrieb_id  = p_betrieb
       and bb.rolle       = 'inhaber'
  ) then
    raise exception 'Nur der Inhaber kann Mitglieder aufnehmen' using errcode = 'insufficient_privilege';
  end if;
  if p_stundensatz < 0 then
    raise exception 'Der Stundensatz darf nicht negativ sein' using errcode = 'check_violation';
  end if;

  select * into v_person from benutzer where lower(email) = v_email;
  if not found then
    raise exception 'Zu % besteht noch kein Konto. Die Person muss sich zuerst registrieren.', v_email
      using errcode = 'no_data_found';
  end if;

  insert into benutzer_betrieb (benutzer_id, betrieb_id, rolle)
  values (v_person.id, p_betrieb, p_rolle)
  on conflict (benutzer_id, betrieb_id) do update set rolle = excluded.rolle;

  -- Mitarbeiterdatensatz nur anlegen, wenn es noch keinen gibt: sonst ginge bei
  -- einer erneuten Aufnahme die Verbindung zu allen bisherigen Zeiteintraegen
  -- verloren.
  if not exists (
    select 1 from mitarbeiter m
     where m.betrieb_id = p_betrieb and m.benutzer_id = v_person.id
  ) then
    insert into mitarbeiter (betrieb_id, benutzer_id, name, stundensatz)
    values (p_betrieb, v_person.id, v_person.anzeigename, p_stundensatz);
  end if;

  return v_person.id;
end $$;

-- ------------------------------------------------------------------- 4 -------
-- Rolle ändern und Mitglied entfernen. Beides nur durch den Inhaber, und beides
-- mit derselben Sperre: der letzte Inhaber darf nicht verschwinden. Sonst
-- entsteht ein Betrieb, den niemand mehr verwalten und niemand mehr löschen
-- kann — betrieb_loeschen() verlangt die Inhaberrolle.
create or replace function mitglied_rolle_setzen(
    p_betrieb  uuid,
    p_benutzer uuid,
    p_rolle    betriebsrolle)
  returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.benutzer_id = v_uid and bb.betrieb_id = p_betrieb and bb.rolle = 'inhaber'
  ) then
    raise exception 'Nur der Inhaber kann Rollen vergeben' using errcode = 'insufficient_privilege';
  end if;

  if p_rolle <> 'inhaber' and not exists (
    select 1 from benutzer_betrieb bb
     where bb.betrieb_id = p_betrieb and bb.rolle = 'inhaber' and bb.benutzer_id <> p_benutzer
  ) then
    raise exception 'Der letzte Inhaber kann seine Rolle nicht abgeben'
      using errcode = 'restrict_violation';
  end if;

  update benutzer_betrieb
     set rolle = p_rolle
   where betrieb_id = p_betrieb and benutzer_id = p_benutzer;
  if not found then
    raise exception 'Diese Person gehoert nicht zum Betrieb' using errcode = 'no_data_found';
  end if;
end $$;

create or replace function mitglied_entfernen(p_betrieb uuid, p_benutzer uuid)
  returns void
  language plpgsql
  security definer
  set search_path = public, pg_temp
  as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.benutzer_id = v_uid and bb.betrieb_id = p_betrieb and bb.rolle = 'inhaber'
  ) then
    raise exception 'Nur der Inhaber kann Mitglieder entfernen' using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1 from benutzer_betrieb bb
     where bb.betrieb_id = p_betrieb and bb.rolle = 'inhaber' and bb.benutzer_id <> p_benutzer
  ) then
    raise exception 'Der letzte Inhaber kann nicht entfernt werden'
      using errcode = 'restrict_violation';
  end if;

  delete from benutzer_betrieb
   where betrieb_id = p_betrieb and benutzer_id = p_benutzer;
  if not found then
    raise exception 'Diese Person gehoert nicht zum Betrieb' using errcode = 'no_data_found';
  end if;

  -- Der Mitarbeiterdatensatz bleibt und wird nur stillgelegt: an ihm haengen
  -- Zeiteintraege, die zu Belegen gehoeren. Loeschen wuerde die Nachkalkulation
  -- zerreissen, und `zeiteintrag.mitarbeiter_id` traegt bewusst
  -- `on delete restrict`.
  update mitarbeiter
     set aktiv = false, benutzer_id = null
   where betrieb_id = p_betrieb and benutzer_id = p_benutzer;
end $$;

-- ------------------------------------------------------------------- 5 -------
-- Rechte. Seit 0017 erbt nichts mehr, also ausdrücklich — und für PUBLIC gilt
-- weiterhin nichts.
revoke all on function konto_anlegen(text)                                  from public, anon, authenticated;
revoke all on function betrieb_gruenden(text)                               from public, anon, authenticated;
revoke all on function mitglied_aufnehmen(uuid, text, betriebsrolle, numeric) from public, anon, authenticated;
revoke all on function mitglied_rolle_setzen(uuid, uuid, betriebsrolle)     from public, anon, authenticated;
revoke all on function mitglied_entfernen(uuid, uuid)                       from public, anon, authenticated;

grant execute on function konto_anlegen(text)                                  to authenticated;
grant execute on function betrieb_gruenden(text)                               to authenticated;
grant execute on function mitglied_aufnehmen(uuid, text, betriebsrolle, numeric) to authenticated;
grant execute on function mitglied_rolle_setzen(uuid, uuid, betriebsrolle)     to authenticated;
grant execute on function mitglied_entfernen(uuid, uuid)                       to authenticated;
