# SpliceVault

R Shiny portal (`ui.R`, `server.R`, `helpers.R`, `global.R`) over a PostgreSQL `misspl_app` schema. The science is in Dawes et al, Nature Genetics 2023;

## Deploys

- Every PR to `main` deploys to the **test** instance on Posit Connect Cloud. Opening or pushing to a PR is a live deploy: confirm with the user first.
- **Prod** is a manual `workflow_dispatch` that also pushes a new git tag. Leave triggering it to the user.
- CI replaces the literal `RELEASE` in `ui.R` with the version tag. Keep that placeholder intact.
- The workflows in `.github/workflows/` are the source of truth.

## Secrets and generated files

`config.yml` and `google-analytics.html` are generated from their `-template` files (by `launch.sh` locally, by CI in deploys) and hold real credentials. Edit the templates. `.env` holds local DB credentials; read values from it only when a task needs them, and keep them out of output and commits.

## R environment

R is pinned to 4.4.3 to match `renv.lock`; CI asserts the match. Add packages with `renv::install()` then `renv::snapshot()`, and add the `library()` call to `dependencies.R`.

## Querying

- `global.R` opens one global connection, `con`. Helpers take a `db` argument but always query through `con`.
- `con` comes from `instrumented_postgres()` in `db.R`, which counts queries for test budgets and adds opt-in latency (`SPLICEVAULT_DB_LATENCY_MS`). Build any new connection or pool on it.
- `db` values are the UI labels `"40K-RNA (hg19)"` and `"300K-RNA (hg38)"`, used as `switch()` keys. The two datasets live in different tables with different column types (e.g. `canonical` is `1`/`0` in 40K, boolean in 300K).
- Build SQL with `glue_sql(..., .con = con)`
- Variant lookups call the Ensembl REST VEP endpoint (`get_variant_data_restapi`), which returns errors as `list(error_text, "error", 1000, "")`.

## Verifying changes

- Run the tests with `./run_tests.sh` (add a filter such as `smoke` to run matching files). It needs only Docker: R and the fixture database both run in containers from `tests/docker-compose.yml`. Tests drive the server function with `shiny::testServer()`, reaching the database through the `test` profile in `config-template.yml`. See `tests/README.md`.
- testthat is test-only: it is installed in `tests/Dockerfile` and kept out of `renv.lock` and `dependencies.R`. Rebuild happens automatically when `renv.lock` changes.
- CI runs the same script (`.github/workflows/test.yaml`) and the test deploy waits for it.
- For changes the tests don't cover, also run the app with `./launch.sh` (needs `.env` and DB access) and exercise the changed path in both datasets.