-- Der Nachtrag als eigene Belegart.
--
-- Allein in dieser Datei, und das ist kein Ordnungssinn: Postgres laesst einen
-- neu hinzugefuegten Enum-Wert in derselben Transaktion nicht verwenden. Steht
-- das ALTER TYPE zusammen mit der ersten Verwendung in einer Migration, bricht
-- das Einspielen ab.
alter type beleg_art add value if not exists 'nachtrag' after 'auftrag';
