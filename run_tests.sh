#!/usr/bin/env bash
# Runs the test suite in Docker against the fixture database.
#
#   ./run_tests.sh                       # every test file
#   ./run_tests.sh smoke                 # only files matching "smoke" (testthat filter)
#   ./run_tests.sh --update-snapshots    # record new and changed snapshots
#   ./run_tests.sh --record-ensembl variant
#                                        # re-record Ensembl REST responses
#
# Needs only Docker. The database is created fresh and removed on every run.
# A normal run fails on a missing or changed snapshot. --update-snapshots
# accepts what the current code produces; review the change with git diff.
# Tests replay recorded Ensembl REST responses and fail on any request with no
# recording. --record-ensembl calls the live Ensembl REST API instead and
# saves its responses; it needs internet access.
set -euo pipefail

cd "$(dirname "$0")"

compose=(docker compose -f tests/docker-compose.yml)
trap '"${compose[@]}" down -v --remove-orphans >/dev/null 2>&1' EXIT

run_args=(--rm)
[ -t 1 ] || run_args+=(-T)

# testthat writes snapshot files at the end of every test file, so
# tests/testthat/_snaps is mounted writable over the read-only repository.
mkdir -p tests/testthat/_snaps
run_args+=(-v "$PWD/tests/testthat/_snaps:/app/tests/testthat/_snaps")

# Recorded Ensembl REST responses, written only with --record-ensembl.
mkdir -p tests/testthat/ensembl

if [ "${1:-}" = "--record-ensembl" ]; then
  shift
  run_args+=(-e RECORD_ENSEMBL=true -e CI=true)
  run_args+=(-v "$PWD/tests/testthat/ensembl:/app/tests/testthat/ensembl")
elif [ "${1:-}" = "--update-snapshots" ]; then
  shift
  run_args+=(-e UPDATE_SNAPSHOTS=true)
else
  # With CI set, testthat fails a missing snapshot rather than recording it.
  # A changed one fails and leaves a .new file beside it for review.
  run_args+=(-e CI=true)
fi

"${compose[@]}" build tests
"${compose[@]}" run "${run_args[@]}" tests "$@"
