-- NUR FÜR LOKALE TESTS, laeuft NACH den Migrationen.
--
-- Ein echtes Supabase-Projekt erteilt den Rollen anon und authenticated per
-- default privileges Tabellenrechte im Schema public. Wer lokal nur
-- 'usage on schema' vergibt, testet die Rechte statt der Policies: der
-- anon-Test waere gruen, weil das RECHT fehlt - und in Produktion leckt es
-- trotzdem, weil dort das Recht da ist und nur die Policy schuetzt.
--
-- Diese Datei stellt den Produktionszustand her, damit der anon-Test die
-- Policies wirklich auf die Probe stellt.
do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
  loop
    execute format('grant select, insert, update, delete on %I to anon', t);
  end loop;
end $$;
