-- Die Absetzung der Abschlaege, in einem Aufruf.
--
-- § 14 Abs. 5 Satz 2 UStG verlangt, in der Schlussrechnung die vereinnahmten
-- Teilentgelte UND die darauf entfallenden Steuerbetraege abzusetzen. Der
-- Trigger aus 0016 laesst eine Schlussrechnung sonst gar nicht erst
-- festschreiben - richtig, aber ohne diese Funktion muesste das Buero die
-- Absetzungszeilen von Hand zusammentragen, je Steuersatz und mit dem damaligen
-- Reverse-Charge-Status. Das macht niemand fehlerfrei.
--
-- Was hier passiert, ist bewusst reines Kopieren: der damalige Steuersatz, der
-- damalige Status, die damalige Belegnummer. Neu gerechnet wird nichts
-- (UStAE 13b.12 Abs. 3 Satz 4), und die Kopie ist zugleich BT-25/BT-26 der
-- EN 16931 - die festgeschriebene Rechnung muss den uebermittelten Wert
-- behalten, auch wenn der Vorbeleg spaeter storniert wird.
create or replace function abschlaege_anrechnen(p_schlussrechnung uuid)
  returns integer
  language plpgsql
  set search_path = public, pg_temp
  as $$
declare
  v_beleg  record;
  v_anzahl integer := 0;
begin
  select b.id, b.betrieb_id, b.projekt_id, b.art, b.status into v_beleg
    from beleg b where b.id = p_schlussrechnung;
  if not found then
    raise exception 'Beleg % nicht gefunden', p_schlussrechnung using errcode = 'no_data_found';
  end if;
  if v_beleg.art <> 'schlussrechnung' then
    raise exception 'Abgesetzt wird nur in einer Schlussrechnung, nicht in einem %', v_beleg.art
      using errcode = 'restrict_violation';
  end if;
  if v_beleg.status <> 'entwurf' then
    raise exception 'Die Schlussrechnung ist bereits festgeschrieben'
      using errcode = 'restrict_violation';
  end if;
  if v_beleg.projekt_id is null then
    raise exception 'Ohne Baustelle laesst sich nicht zuordnen, welche Abschlaege dazugehoeren'
      using errcode = 'restrict_violation';
  end if;

  -- Kein Filter auf den Belegstatus der Abschlagsrechnung: ein Storno entfernt
  -- sie NICHT aus der Absetzungsbasis (UStAE 14.8 Abs. 9 Satz 1).
  insert into beleg_anrechnung (
    betrieb_id, schlussrechnung_id, abschlagsrechnung_id, zahlung_id, vereinnahmt_am,
    entgelt_netto, steuersatz, steuerbetrag, angerechnet_brutto, status_rc,
    vorbeleg_nummer, vorbeleg_datum
  )
  select
    v_beleg.betrieb_id, v_beleg.id, ab.id, z.id, z.vereinnahmt_am,
    z.entgelt_netto, z.steuersatz, z.steuerbetrag, z.betrag_brutto, z.status_rc,
    ab.nummer, ab.datum
  from zahlung z
  join beleg ab on ab.betrieb_id = z.betrieb_id and ab.id = z.beleg_id
  where ab.betrieb_id = v_beleg.betrieb_id
    and ab.projekt_id = v_beleg.projekt_id
    and ab.art in ('abschlagsrechnung', 'teilrechnung')
    and ab.nummer is not null
    and not exists (
      select 1 from beleg_anrechnung a
       where a.schlussrechnung_id = v_beleg.id and a.zahlung_id = z.id
    );

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end $$;

revoke all on function abschlaege_anrechnen(uuid) from public, anon, authenticated;
grant execute on function abschlaege_anrechnen(uuid) to authenticated;
