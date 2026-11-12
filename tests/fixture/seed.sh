#!/usr/bin/env bash
# Rebuilds tests/fixture/fixture.sql.gz from the production database.
#
# Needs: Docker, R with the project's renv library, and a config.yml whose
# "default" profile (or SEED_SOURCE_CONFIG) has read access to production.
# Run from anywhere:  tests/fixture/seed.sh
set -euo pipefail

cd "$(dirname "$0")/../.."

PG_IMAGE=postgres:13   # matches the production server major version
STAGING=splicevault-fixture-staging
export STAGING_PORT=55433

docker rm -f "$STAGING" >/dev/null 2>&1 || true
docker run -d --name "$STAGING" -e POSTGRES_PASSWORD=staging -p "127.0.0.1:$STAGING_PORT:5432" "$PG_IMAGE" >/dev/null
trap 'docker rm -f "$STAGING" >/dev/null' EXIT

# TCP check: the init-time server listens on the socket only.
for _ in $(seq 60); do
  docker exec "$STAGING" pg_isready -h 127.0.0.1 -U postgres -q && break
  sleep 1
done
docker exec "$STAGING" pg_isready -h 127.0.0.1 -U postgres -q \
  || { echo "Staging database did not start" >&2; exit 1; }

# Production connection details, exported for pg_dump only (never printed).
# Only the line starting with "export PGHOST=" is used, so renv or config
# messages on stdout cannot leak into the eval.
src_env="$(Rscript -e '
  conn_args <- config::get("dataconnection", config = Sys.getenv("SEED_SOURCE_CONFIG", "default"), file = "config.yml")
  cat(sprintf("export PGHOST=%s PGPORT=%s PGUSER=%s PGDATABASE=%s PGPASSWORD=%s\n",
              shQuote(conn_args$host), conn_args$port, shQuote(conn_args$user),
              shQuote(conn_args$dbname), shQuote(conn_args$password)))
' | grep '^export PGHOST=' || true)"
[ -n "$src_env" ] || { echo "Could not read the source profile from config.yml" >&2; exit 1; }
eval "$src_env"
unset src_env

echo "Copying production schema"
docker run --rm -e PGHOST -e PGPORT -e PGUSER -e PGDATABASE -e PGPASSWORD "$PG_IMAGE" \
  pg_dump --schema-only --no-owner --no-privileges -n misspl_app \
  | docker exec -i "$STAGING" psql -q -U postgres -v ON_ERROR_STOP=1 >/dev/null
unset PGHOST PGPORT PGUSER PGDATABASE PGPASSWORD

echo "Copying fixture rows"
Rscript tests/fixture/seed_fixture.R

echo "Writing tests/fixture/fixture.sql.gz"
# Drop psql \restrict lines so older psql clients (e.g. on CI runners) can load
# it. gzip -n keeps the output byte-identical when the data has not changed.
tmp_fixture=$(mktemp tests/fixture/fixture.sql.gz.XXXXXX)
if ! docker exec "$STAGING" pg_dump -U postgres --no-owner --no-privileges -n misspl_app \
  | sed -E '/^\\(un)?restrict /d' | gzip -n -9 > "$tmp_fixture"; then
  rm -f "$tmp_fixture"
  exit 1
fi
mv "$tmp_fixture" tests/fixture/fixture.sql.gz

ls -lh tests/fixture/fixture.sql.gz
