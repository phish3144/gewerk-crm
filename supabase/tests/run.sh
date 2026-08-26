#!/usr/bin/env bash
# Schema und Sicherheitsregeln gegen einen echten Postgres pruefen.
#
#   ./supabase/tests/run.sh
#
# Startet bei Bedarf einen lokalen Cluster, legt die Datenbank neu an, spielt
# alle Migrationen ein und laesst die Testdateien laufen. Exit 0 nur, wenn jede
# Datei durchlaeuft.
set -euo pipefail
cd "$(dirname "$0")/../.."

PGBIN=${PGBIN:-/usr/lib/postgresql/16/bin}
PGDATA=${PGDATA:-/var/lib/pgtest/data}
PORT=${PGPORT:-5433}
DB=${PGDATABASE:-gewerk}
export PGHOST=127.0.0.1 PGPORT=$PORT PGUSER=postgres

if ! pg_isready -q; then
  echo "Starte lokalen Postgres auf Port $PORT ..."
  su postgres -c "$PGBIN/pg_ctl -D $PGDATA -o '-p $PORT -c listen_addresses=127.0.0.1' -l /var/lib/pgtest/log start"
  for _ in $(seq 10); do pg_isready -q && break; sleep 1; done
fi

dropdb --if-exists "$DB"
createdb "$DB"

# Der Shim bildet nach, was Supabase bereits mitbringt: auth.uid() und die Rollen.
# Er wird NIE auf ein Supabase-Projekt angewendet.
psql -d "$DB" -v ON_ERROR_STOP=1 -q -f supabase/local/00_shim.sql
for m in supabase/migrations/*.sql; do
  psql -d "$DB" -v ON_ERROR_STOP=1 -q -f "$m"
done
echo "Migrationen eingespielt: $(ls supabase/migrations/*.sql | wc -l)"

fehler=0
for t in supabase/tests/*.sql; do
  if ausgabe=$(psql -d "$DB" -v ON_ERROR_STOP=1 -q -f "$t" 2>&1); then
    echo "$ausgabe" | grep -E '^  OK' || echo "  OK  $(basename "$t")"
  else
    fehler=1
    echo "  FEHLER $(basename "$t")"
    echo "$ausgabe" | grep -E 'ERROR|FAIL' | head -5 | sed 's/^/        /'
  fi
done
[ $fehler -eq 0 ] && echo "Alle Tests gruen." || { echo "Tests fehlgeschlagen."; exit 1; }
