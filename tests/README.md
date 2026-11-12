# Tests

The tests drive the Shiny server function through `shiny::testServer()`
against a small fixture database. The app reaches it through the `test`
profile in `config-template.yml`, so no real credentials are needed.

## Running the tests

Needs only Docker. From anywhere in the repository:

```bash
./run_tests.sh          # every test file
./run_tests.sh smoke    # only files whose name matches "smoke"
```

The script uses `tests/docker-compose.yml` to:

1. build the runner image from `tests/Dockerfile` (R 4.4.3, the packages in
   `renv.lock` and testthat). Docker reuses it until `renv.lock` or the
   Dockerfile changes.
2. start a fresh fixture database (PostgreSQL 13, loaded from
   `tests/fixture/fixture.sql.gz`) and wait for it to be ready.
3. run `tests/testthat.R` in the runner, with the repository mounted
   read-only, so code edits need no rebuild.
4. remove both containers and the database, pass or fail.

While a run is in progress the database is also published on host port
55432 (user and password `splicevault`) for debugging with `psql`.

CI runs the same script (`.github/workflows/test.yaml`) and the test
deployment waits for it to pass.

## Driving the input form

`shiny::testServer()` has no browser, so server updates to inputs (new
dropdown selections, Restore Settings) never reach `input` on their own.
`recording_session()` in `tests/testthat/helper-app.R` records what the server
sends, and `settle()` plays the browser's part: it applies those values (and
the selected tissue whenever the tissue dropdown renders) until nothing
changes. Wrap a test in `with_app()`, use `open_app()` to load the form and
`user_sets()` for each user action, then assert on what the user sees: `dropdown()`, `selected_label()`,
`tissue_options()` and `js_state()` for enabled buttons.
`tests/testthat/test-dropdowns.R` pins the dropdown chain, tissue dropdown,
Generate Table button and Restore Settings this way.

## The fixture database

`tests/fixture/fixture.sql.gz` is the production `misspl_app` schema plus the
rows for five small genes (HBA1, HBB, INS, CNN2, SMN1): for each dataset and
transcript type, the canonical transcript and one non-canonical one, with
every exon, splice site, event and per-tissue count for them.
`tests/testthat/test-fixture.R` checks it covers:

- both datasets (300K-RNA hg38, 40K-RNA hg19) and both transcript types
- canonical and non-canonical transcripts
- both strands
- a splice site with many events (more than one table page)
- a splice site with no events in a tissue (every production splice site has
  at least its annotated event, so "no events" shows up in tissue mode)
- every clinically accessible tissue

### Reseeding from production

This needs read access to production, so a maintainer runs it by hand. With
production credentials in the `default` profile of a local `config.yml`
(gitignored):

```bash
tests/fixture/seed.sh
```

It copies the production schema and the rows for the genes listed in
`tests/fixture/seed_fixture.R` into a throwaway container, then writes
`tests/fixture/fixture.sql.gz`. Set `SEED_SOURCE_CONFIG` to read a different
`config.yml` profile. Rerun the tests after reseeding.
