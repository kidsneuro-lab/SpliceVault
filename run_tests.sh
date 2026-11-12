#!/usr/bin/env bash
# Runs the test suite in Docker against the fixture database.
#
#   ./run_tests.sh          # every test file
#   ./run_tests.sh smoke    # only files matching "smoke" (testthat filter)
#
# Needs only Docker. The database is created fresh and removed on every run.
set -euo pipefail

cd "$(dirname "$0")"

compose=(docker compose -f tests/docker-compose.yml)
trap '"${compose[@]}" down -v --remove-orphans >/dev/null 2>&1' EXIT

tty_flag=()
[ -t 1 ] || tty_flag=(-T)

"${compose[@]}" build tests
# The ${a[@]+...} form keeps bash 3.2 (macOS) happy with an empty array.
"${compose[@]}" run --rm ${tty_flag[@]+"${tty_flag[@]}"} tests "$@"
