#!/usr/bin/env bash
# One-shot migration of the database from PostgreSQL 15 to 18 (dump + restore).
#
# Run on the VPS, from the project directory, AFTER pulling the version of
# docker-compose.prod.yml that uses postgres:18 + volume db_data_pg18,
# while the old Postgres 15 container is still running.
#
#   ./scripts/migrate-postgres-15-to-18.sh
#
# The old volume (db_data) is never modified: rollback = put postgres:15 and
# db_data:/var/lib/postgresql/data back in the compose file, then
# `docker compose -f docker-compose.prod.yml up -d database django nextjs`.
#
# Overridable for testing: COMPOSE_FILE, DB_CONTAINER, DB_SERVICE, APP_SERVICES, BACKUP_DIR.

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
DB_CONTAINER="${DB_CONTAINER:-nextstep_database}"
DB_SERVICE="${DB_SERVICE:-database}"
APP_SERVICES="${APP_SERVICES-django nextjs}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

COMPOSE=(docker compose -f "$COMPOSE_FILE")
STAMP="$(date +%Y%m%d-%H%M%S)"
DUMP_FILE="$BACKUP_DIR/pg15-before-18-$STAMP.dump"
COUNTS_BEFORE="$BACKUP_DIR/pg15-rowcounts-$STAMP.txt"
COUNTS_AFTER="$BACKUP_DIR/pg18-rowcounts-$STAMP.txt"

# Exact row count of every table in the public schema (works on 15 and 18).
ROWCOUNT_SQL="select table_name || '|' || (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name), false, true, '')))[1]::text from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE' order by 1"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

db_exec() { docker exec -i "$DB_CONTAINER" sh -c "$1"; }
psql_q()  { db_exec "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -v ON_ERROR_STOP=1 -tAc \"$1\""; }

on_error() {
    cat >&2 <<EOF

Migration aborted. The Postgres 15 data volume (db_data) was NOT touched.
Dump (if created): $DUMP_FILE
To roll back: restore postgres:15 + "db_data:/var/lib/postgresql/data" in $COMPOSE_FILE,
then run: docker compose -f $COMPOSE_FILE up -d $DB_SERVICE $APP_SERVICES
EOF
}
trap on_error ERR

# --- 0. Preconditions ----------------------------------------------------------
log "Checking preconditions"
grep -q 'image: postgres:18' "$COMPOSE_FILE" \
    || fail "$COMPOSE_FILE does not use postgres:18 yet — pull the updated compose file first."

current_major="$(psql_q 'show server_version_num' | cut -c1-2)"
[ "$current_major" = "15" ] \
    || fail "Running database is Postgres $current_major, expected 15. Nothing to migrate?"

mkdir -p "$BACKUP_DIR"
"${COMPOSE[@]}" pull "$DB_SERVICE"

# --- 1. Freeze writes ----------------------------------------------------------
if [ -n "$APP_SERVICES" ]; then
    log "Stopping app services ($APP_SERVICES) — site is down from here"
    # shellcheck disable=SC2086
    "${COMPOSE[@]}" stop $APP_SERVICES
fi

# --- 2. Dump Postgres 15 -------------------------------------------------------
log "Dumping Postgres 15 to $DUMP_FILE"
db_exec 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$DUMP_FILE"
[ -s "$DUMP_FILE" ] || fail "Dump file is empty."
db_exec 'pg_restore --list' < "$DUMP_FILE" > /dev/null || fail "Dump file is not readable."
psql_q "$ROWCOUNT_SQL" > "$COUNTS_BEFORE"
echo "Dump OK ($(du -h "$DUMP_FILE" | cut -f1)), $(wc -l < "$COUNTS_BEFORE" | tr -d ' ') tables."

# --- 3. Start Postgres 18 on the new volume -----------------------------------
log "Recreating $DB_SERVICE with Postgres 18 (new volume, old one kept)"
"${COMPOSE[@]}" up -d --force-recreate "$DB_SERVICE"

for _ in $(seq 1 60); do
    db_exec 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > /dev/null 2>&1 && break
    sleep 2
done
db_exec 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > /dev/null || fail "Postgres 18 did not become ready."

new_major="$(psql_q 'show server_version_num' | cut -c1-2)"
[ "$new_major" = "18" ] || fail "New database is Postgres $new_major, expected 18."
[ "$(psql_q "select count(*) from information_schema.tables where table_schema = 'public'")" = "0" ] \
    || fail "The Postgres 18 database is not empty — refusing to restore over it."

# --- 4. Restore + verify -------------------------------------------------------
log "Restoring dump into Postgres 18"
db_exec 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --exit-on-error' < "$DUMP_FILE"
psql_q 'analyze' > /dev/null

psql_q "$ROWCOUNT_SQL" > "$COUNTS_AFTER"
if ! diff -u "$COUNTS_BEFORE" "$COUNTS_AFTER"; then
    fail "Row counts differ between 15 and 18 (see diff above). App services left stopped."
fi
echo "Row counts identical on every table."

# --- 5. Restart the app --------------------------------------------------------
if [ -n "$APP_SERVICES" ]; then
    log "Starting app services"
    # shellcheck disable=SC2086
    "${COMPOSE[@]}" up -d $APP_SERVICES
fi

trap - ERR
log "Done: Postgres $(psql_q 'show server_version')"
cat <<EOF
Backup kept at: $DUMP_FILE
Once the site has been checked for a few days, the old volume can be removed:
  docker volume ls | grep db_data      # find the exact name (prefixed by the project)
  docker volume rm <project>_db_data
EOF
