-- Härtung nach dem Supabase-Datenbank-Linter. Drei Befunde, zwei davon echt.

-- 1. Erweiterungen gehören nicht in das Schema, das die API ausliefert.
create schema if not exists extensions;
alter extension btree_gist set schema extensions;

-- 2. journal_schreiben() ist eine Trigger-Funktion und läuft als security
--    definer. Sie hat über die REST-Schnittstelle nichts zu suchen — weder für
--    angemeldete noch für anonyme Aufrufer. Ein Direktaufruf würde zwar an
--    "trigger functions can only be called as triggers" scheitern, aber eine
--    security-definer-Funktion offen stehen zu lassen ist keine Frage des
--    tatsächlichen Schadens.
revoke all on function journal_schreiben() from public;

-- 3. meine_betriebe() bleibt für 'authenticated' aufrufbar — die Policies
--    brauchen sie. Für 'anon' nicht: dort ist auth.uid() null, die Funktion
--    gäbe eine leere Menge zurück, aber sie gehört trotzdem nicht in die
--    öffentliche Oberfläche.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    execute 'revoke all on function journal_schreiben() from anon';
    execute 'revoke all on function meine_betriebe()   from anon';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'revoke all on function journal_schreiben() from authenticated';
    -- meine_betriebe bleibt bewusst erlaubt
    execute 'grant execute on function meine_betriebe() to authenticated';
  end if;
end $$;
