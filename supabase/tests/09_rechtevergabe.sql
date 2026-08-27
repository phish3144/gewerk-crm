-- Rechtevergabe. Prueft die Ebene unter den Policies: wer ueberhaupt ein Recht
-- auf ein Objekt besitzt.
--
-- Diese Datei ist bewusst datengetrieben. Sie liest Tabellen und Funktionen aus
-- dem Katalog, nicht aus einer gepflegten Liste - eine Tabelle, die eine spaetere
-- Migration anlegt, ist damit ab dem ersten Lauf mitgeprueft. Nur die
-- Freigabeliste der aufrufbaren Funktionen steht ausgeschrieben da, denn genau
-- die ist die Entscheidung.
--
-- Voraussetzung: 00_shim.sql hat die Supabase-Standardrechte gesetzt. Ohne sie
-- prueft der Lauf eine Datenbank, die strenger ist als die echte, und jede
-- Zusicherung hier waere wertlos.

\set ON_ERROR_STOP on

-- --------------------------------------------------------------- 1: anon -----
-- Kein Recht auf kein Objekt. Nicht "sieht nichts" - das waere die Policy.
do $$
declare fund text[] := '{}';
begin
  select coalesce(array_agg(c.relname || ' (' || array_to_string(c.relacl, ',') || ')'
                            order by c.relname), '{}')
    into fund
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'v', 'm')
     and exists (select 1 from aclexplode(c.relacl) a
                  where a.grantee = 'anon'::regrole);
  if array_length(fund, 1) > 0 then
    raise exception 'FAIL anon hat Tabellenrechte: %', array_to_string(fund, ', ');
  end if;
end $$;

do $$
declare fund text[] := '{}';
begin
  select coalesce(array_agg(p.proname order by p.proname), '{}')
    into fund
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and exists (select 1 from aclexplode(p.proacl) a
                  where a.grantee = 'anon'::regrole);
  if array_length(fund, 1) > 0 then
    raise exception 'FAIL anon darf Funktionen ausfuehren: %', array_to_string(fund, ', ');
  end if;
end $$;

-- Keine Funktion darf ueber PUBLIC offenstehen. proacl null heisst genau das:
-- Standardrecht, und der Standard fuer Funktionen ist EXECUTE fuer PUBLIC.
do $$
declare fund text[] := '{}';
begin
  select coalesce(array_agg(p.proname || case when p.prosecdef then ' (security definer)' else '' end
                            order by p.proname), '{}')
    into fund
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and (p.proacl is null
          or exists (select 1 from aclexplode(p.proacl) a where a.grantee = 0));
  if array_length(fund, 1) > 0 then
    raise exception 'FAIL Funktion steht PUBLIC offen: %', array_to_string(fund, ', ');
  end if;
end $$;

-- ------------------------------------------------------ 2: authenticated -----
-- Genau die vier Datenrechte, nichts darueber. TRUNCATE ist der wichtige Fall:
-- es unterliegt keiner Policy und feuert keinen Zeilentrigger.
do $$
declare fund text[] := '{}';
begin
  select coalesce(array_agg(c.relname || ': ' || a.privilege_type order by c.relname, a.privilege_type), '{}')
    into fund
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join lateral aclexplode(c.relacl) a
   where n.nspname = 'public' and c.relkind in ('r', 'v', 'm')
     and a.grantee = 'authenticated'::regrole
     and a.privilege_type not in ('SELECT', 'INSERT', 'UPDATE', 'DELETE');
  if array_length(fund, 1) > 0 then
    raise exception 'FAIL authenticated hat mehr als die vier Datenrechte: %', array_to_string(fund, ', ');
  end if;
end $$;

-- journal ist anfuegend und wird nur vom security-definer-Trigger gefuellt.
-- Schreibrechte der Anwendungsrolle darf es darauf nicht geben.
do $$
declare fund text[] := '{}';
begin
  select coalesce(array_agg(a.privilege_type order by a.privilege_type), '{}')
    into fund
    from pg_class c cross join lateral aclexplode(c.relacl) a
   where c.oid = 'journal'::regclass
     and a.grantee = 'authenticated'::regrole
     and a.privilege_type <> 'SELECT';
  if array_length(fund, 1) > 0 then
    raise exception 'FAIL authenticated darf auf journal schreiben: %', array_to_string(fund, ', ');
  end if;
end $$;

-- nummernkreis: lesen ja, schreiben nein.
do $$
declare fund text[] := '{}';
begin
  select coalesce(array_agg(a.grantee::regrole::text || ':' || a.privilege_type
                            order by a.grantee::regrole::text, a.privilege_type), '{}')
    into fund
    from pg_class c cross join lateral aclexplode(c.relacl) a
   where c.oid = 'nummernkreis'::regclass
     and a.grantee in ('anon'::regrole, 'authenticated'::regrole)
     and a.privilege_type <> 'SELECT';
  if array_length(fund, 1) > 0 then
    raise exception 'FAIL nummernkreis ist beschreibbar: %', array_to_string(fund, ', ');
  end if;
end $$;

-- --------------------------------------------- 3: Freigabeliste Funktionen ---
-- Die einzige ausgeschriebene Liste der Datei. Weicht der Katalog ab, ist
-- entweder eine Funktion aufgemacht worden oder eine gewollte fehlt.
do $$
declare
  erlaubt text[] := array[
    'beleg_festschreiben',
    'beleg_summen_neu',
    'betrieb_gruenden',
    'betrieb_loeschen',
    'einheit_gruppe',        -- aus den Sichten heraus, die security_invoker laufen
    'konto_anlegen',
    'mitglied_aufnehmen',
    'mitglied_entfernen',
    'mitglied_rolle_setzen',
    'loeschung_laeuft_fuer',   -- aus Invoker-Triggern heraus aufgerufen, siehe 0017
    'meine_betriebe',
    'meine_betriebe_inhaber',
    'meine_betriebe_schreibend',
    'nummer_praefix'
  ];
  ist     text[];
  zuviel  text[];
  zuwenig text[];
begin
  select coalesce(array_agg(distinct p.proname order by p.proname), '{}')
    into ist
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and exists (select 1 from aclexplode(p.proacl) a
                  where a.grantee = 'authenticated'::regrole and a.privilege_type = 'EXECUTE');

  select coalesce(array_agg(x order by x), '{}') into zuviel
    from unnest(ist) x where x <> all (erlaubt);
  select coalesce(array_agg(x order by x), '{}') into zuwenig
    from unnest(erlaubt) x where x <> all (ist);

  if array_length(zuviel, 1) > 0 then
    raise exception 'FAIL authenticated darf Funktionen ausfuehren, die nicht freigegeben sind: %',
      array_to_string(zuviel, ', ');
  end if;
  if array_length(zuwenig, 1) > 0 then
    raise exception 'FAIL freigegebene Funktion ist nicht ausfuehrbar: %',
      array_to_string(zuwenig, ', ');
  end if;
end $$;

-- ------------------------------------------------------ 4: TRUNCATE live -----
-- Der Nachweis am lebenden Objekt, nicht am Katalog. Angelegt werden zwei
-- Betriebe mit je einem Beleg; die Nutzerin gehoert nur zum ersten.
do $$
begin
  insert into betrieb (id, name) values
    ('e9000000-0000-0000-0000-00000000000a', 'Rechte-Test A'),
    ('e9000000-0000-0000-0000-00000000000b', 'Rechte-Test B');
  insert into benutzer (id, email, anzeigename)
    values ('e9000000-1111-0000-0000-00000000000a', 'rechte@test.de', 'Rechte-Testerin');
  insert into benutzer_betrieb (benutzer_id, betrieb_id, rolle)
    values ('e9000000-1111-0000-0000-00000000000a', 'e9000000-0000-0000-0000-00000000000a', 'inhaber');
  insert into kunde (betrieb_id, nummer, name) values
    ('e9000000-0000-0000-0000-00000000000a', 'RT-A', 'Kunde A'),
    ('e9000000-0000-0000-0000-00000000000b', 'RT-B', 'Kunde B');
  insert into beleg (betrieb_id, art, kunde_id, datum, erstellt_von)
    select k.betrieb_id, 'angebot', k.id, current_date, 'e9000000-1111-0000-0000-00000000000a'
      from kunde k where k.nummer in ('RT-A', 'RT-B');
end $$;

set role authenticated;
set request.jwt.claim.sub = 'e9000000-1111-0000-0000-00000000000a';

do $$
declare n integer;
begin
  select count(*) into n from beleg
   where betrieb_id in ('e9000000-0000-0000-0000-00000000000a',
                        'e9000000-0000-0000-0000-00000000000b');
  if n <> 1 then
    raise exception 'FAIL Testaufbau: die Nutzerin sieht % Belege statt 1', n;
  end if;

  begin
    execute 'truncate beleg cascade';
    raise exception 'FAIL TRUNCATE auf beleg war erlaubt - Policies und Zeilentrigger greifen dabei nicht';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

do $$
declare n integer;
begin
  select count(*) into n from beleg
   where betrieb_id in ('e9000000-0000-0000-0000-00000000000a',
                        'e9000000-0000-0000-0000-00000000000b');
  if n <> 2 then
    raise exception 'FAIL nach dem TRUNCATE-Versuch sind % von 2 Belegen uebrig', n;
  end if;
end $$;

-- --------------------------------------------- 5: naechste_nummer direkt -----
-- Der Nummernkreis darf nur ueber beleg_festschreiben fortschreiten.
set role authenticated;
set request.jwt.claim.sub = 'e9000000-1111-0000-0000-00000000000a';

do $$
begin
  begin
    perform naechste_nummer('e9000000-0000-0000-0000-00000000000b'::uuid,
                            'schlussrechnung'::beleg_art, 2026::smallint);
    raise exception 'FAIL naechste_nummer war direkt aufrufbar - jeder Aufruf reisst eine Luecke';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

-- Aufraeumen ausschliesslich ueber betrieb_loeschen: das Journal ist anfuegend,
-- ein direktes DELETE darauf scheitert auch als postgres am Trigger aus 0011.
-- Der Loeschpfad laeuft damit gleich als Zugabe mit.
insert into benutzer_betrieb (benutzer_id, betrieb_id, rolle)
  values ('e9000000-1111-0000-0000-00000000000a', 'e9000000-0000-0000-0000-00000000000b', 'inhaber');

set role authenticated;
set request.jwt.claim.sub = 'e9000000-1111-0000-0000-00000000000a';
select betrieb_loeschen('e9000000-0000-0000-0000-00000000000a');
select betrieb_loeschen('e9000000-0000-0000-0000-00000000000b');
reset role;
delete from benutzer where id = 'e9000000-1111-0000-0000-00000000000a';

do $$
declare n integer;
begin
  select count(*) into n from journal
   where betrieb_id in ('e9000000-0000-0000-0000-00000000000a',
                        'e9000000-0000-0000-0000-00000000000b');
  if n <> 0 then
    raise exception 'FAIL nach betrieb_loeschen sind % Journalzeilen uebrig', n;
  end if;
end $$;

\echo '  OK  Rechtevergabe: anon entrechtet, kein TRUNCATE, Funktionsfreigabe vollstaendig'
