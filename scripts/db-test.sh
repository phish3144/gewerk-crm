#!/usr/bin/env bash
# Baut eine frische Datenbank auf, spielt alle Migrationen ein und laesst die
# Tests laufen. Bricht beim ersten Fehler ab.
#
# Braucht einen lokalen Postgres. Der Shim unter supabase/local/ bildet nach,
# was Supabase mitbringt (auth-Schema, auth.uid(), die drei Rollen) - er wird
# NIE auf ein Supabase-Projekt angewendet.
set -euo pipefail

PGBIN=${PGBIN:-/usr/lib/postgresql/16/bin}
PGDATA=${PGDATA:-/var/lib/pgtest/data}
PGPORT=${PGPORT:-5433}
PGHOST=${PGHOST:-127.0.0.1}
DB=${DB:-gewerk}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if ! pg_isready -h "$PGHOST" -p "$PGPORT" -q 2>/dev/null; then
  echo "==> Postgres starten"
  PGU=$(id -u postgres >/dev/null 2>&1 && echo postgres || echo "$USER")
  su "$PGU" -c "$PGBIN/pg_ctl -D $PGDATA -o '-p $PGPORT -c listen_addresses=$PGHOST' -l /var/lib/pgtest/log start"
  sleep 2
fi

echo "==> Datenbank neu aufbauen"
dropdb   -h "$PGHOST" -p "$PGPORT" -U postgres --if-exists "$DB"
createdb -h "$PGHOST" -p "$PGPORT" -U postgres "$DB"

echo "==> Migrationen"
ARGS=(-f "$ROOT/supabase/local/00_shim.sql")
for f in "$ROOT"/supabase/migrations/*.sql; do ARGS+=(-f "$f"); done
psql -h "$PGHOST" -p "$PGPORT" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q "${ARGS[@]}"

echo "==> Tests"
for t in "$ROOT"/supabase/tests/*.sql; do
  psql -h "$PGHOST" -p "$PGPORT" -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q \
       -f "$t" 2>&1 | grep -v '^psql.*NOTICE' || true
done

echo "==> Kontrastwerte der Design-Tokens"
python3 "$ROOT/scripts/kontrast.py"

echo
echo "Alles gruen."
