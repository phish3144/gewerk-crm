-- Das Journal war nur ueber REVOKE gegen Aenderung geschuetzt. Das genuegt nicht:
-- ein Superuser umgeht Rechtepruefungen vollstaendig, und der Tabelleneigentuemer
-- kann sich das Recht jederzeit selbst zurueckgeben. Beides faellt bei einer
-- Betriebspruefung auf die Aussage "unveraenderbar" zurueck.
--
-- Der eigene Test hat es aufgedeckt: als Eigentuemer ging
--   update journal set aktion = 'insert'
-- widerstandslos durch.
--
-- Ein Trigger greift dagegen unabhaengig von der Rolle.
create or replace function journal_ist_anfuegend()
  returns trigger
  language plpgsql
  set search_path = public, pg_temp
  as $$
begin
  raise exception
    'Das Journal ist anfuegend. % ist auf journal nicht zulaessig (GoBD, Unveraenderbarkeit).', tg_op
    using errcode = 'restrict_violation';
end $$;

create trigger trg_journal_kein_update
  before update on journal
  for each row execute function journal_ist_anfuegend();

create trigger trg_journal_kein_delete
  before delete on journal
  for each row execute function journal_ist_anfuegend();

-- TRUNCATE umgeht Zeilentrigger, deshalb zusaetzlich ein Statement-Trigger.
create trigger trg_journal_kein_truncate
  before truncate on journal
  for each statement execute function journal_ist_anfuegend();
