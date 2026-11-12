# Tests

The tests drive the Shiny server function through `shiny::testServer()`
against a small fixture database. The app reaches it through the `test`
profile in `config-template.yml`, so no real credentials are needed.

## Running the tests

Needs only Docker. From anywhere in the repository:

```bash
./run_tests.sh                      # every test file
./run_tests.sh smoke                # only files whose name matches "smoke"
./run_tests.sh --update-snapshots   # record new and changed snapshots
```

The script uses `tests/docker-compose.yml` to:

1. build the runner image from `tests/Dockerfile` (R 4.4.3, the packages in
   `renv.lock` and testthat). Docker reuses it until `renv.lock` or the
   Dockerfile changes.
2. start a fresh fixture database (PostgreSQL 13, loaded from
   `tests/fixture/fixture.sql.gz`) and wait for it to be ready.
3. run `tests/testthat.R` in the runner, with the repository mounted
   read-only, so code edits need no rebuild. `tests/testthat/_snaps` is
   mounted writable, since testthat rewrites snapshot files as it goes.
4. remove both containers and the database, pass or fail.

While a run is in progress the database is also published on host port
55432 (user and password `splicevault`) for debugging with `psql`.

CI runs the same script (`.github/workflows/test.yaml`) and the test
deployment waits for it to pass.

## Input form scenarios

Three files pin how the form behaves today, in scenarios a developer or
domain expert can read one at a time:

- `tests/testthat/test-ui.R`: what the page opens with (Variant tab, default
  settings, tissue list, dropdowns filled behind the Variant tab), greying out
  of sliders by the "Show all" boxes, Restore Settings and the Generate Table
  button. Runs on the page defaults (300K-RNA, RefSeq).
- `tests/testthat/test-300k.R` and `test-40k.R`: the gene, transcript and
  exon dropdowns on each dataset, for RefSeq and Ensembl, including switching
  dataset, transcript type, transcript, gene and splice site, plus the
  dataset's tissue dropdown behaviour.

```r
it("picking another transcript lists its exons, and the exon goes back to the first exon", {
  with_app({
    # Given
    user_opens_app(session)
    user_selects(session, "Tab", "Gene/Transcript/Exon")
    user_selects(session, "Exon", "3 (g.1032391)")

    # When
    user_selects(session, "Transcript", "NM_001303499")

    # Then
    expect_selected(session, "Transcript", "NM_001303499")
    expect_dropdown(session, "Exon", options = c("2 (g.1031070)", ...), selected = "2 (g.1031070)")
  })
})
```

Conventions:

- Write inputs and expected values out in full, as the exact text the user
  sees. No loops or lookup tables, even where scenarios repeat.
- The app opens as the real page does: `user_opens_app()` starts from the
  defaults in `ui.R` (read from the rendered page), on the Variant tab.
  Dropdown scenarios select the Gene/Transcript/Exon tab, then the dataset and
  transcript type they need.
- Switch scenarios start from CNN2, its canonical transcript and the second
  exon in the dropdown, so a reset to the first exon is visible.
- Name fields, settings and buttons by their labels on screen. The actions
  are `user_opens_app()`, `user_selects()` (dropdowns, tabs and radio
  buttons), `user_clears()`, `user_changes()` and `user_clicks()`; the checks
  are `expect_dropdown()`, `expect_selected()`, `expect_hidden()`,
  `expect_setting()` and `expect_enabled()`. All are in
  `tests/testthat/helper-app.R`, which is the only place input IDs and
  database IDs appear.
- When a scenario pins behaviour that has an open issue, end its name with
  "(current behaviour, see #NN)" and update it when the issue is fixed.
- Events table contents belong to the table tests, not here.

## Events table scenarios

`tests/testthat/test-table-300k.R` and `test-table-40k.R` pin the events
table as the user sees it after clicking Generate Table, on one anchor splice
site per dataset (named at the top of each file):

- snapshots of the whole table, with default settings and with every "Show
  all" box ticked, in all tissues and (300K-RNA) one tissue
- one scenario per filter ("Number of Events", "Maximum Number of Exons
  Skipped", "Show Cryptics Within"), checking the title and the events listed
- a splice site where only the annotated event is left, and (300K-RNA) a
  tissue with no events at the splice site

The checks are `expect_table_title()` and `expect_events()`, which compares
the columns you name (by their headers on screen) row by row. Snapshots use
`expect_snapshot(print_events_table(session))`, which prints the title, the
accessible tissues legend and every cell of every row. Cells hold the values
sent to the browser: DT then shows "Yes" as a tick and "No" as blank, and
trims the trailing comma from the accessible tissues.

Snapshots live in `tests/testthat/_snaps/`. A run fails on a missing or
changed snapshot and leaves a `.new.md` file beside a changed one. When a
change is intended, run `./run_tests.sh --update-snapshots` and review the
change with `git diff`. Reseeding the fixture database changes them too.

Keep anchor splice sites free of tied sample counts: the table is ordered by
sample count alone, so tied events can come back in any order (#67). A
missing annotated event makes the table error today, so it is not pinned
(#66).

`shiny::testServer()` has no browser, so server updates to inputs (new
dropdown selections, Restore Settings) never reach `input` on their own. The
helpers record what the server sends and `settle()` plays the browser's part,
applying those values until nothing changes.

## Query budgets

Each round trip to the remote production database is slow, and the local
fixture hides that cost. So tests count the queries a user interaction makes
and assert a budget for it. `count_queries()` (in
`tests/testthat/helper-app.R`) returns how many queries ran while its
argument was evaluated. Wrap a user action in a scenario with it:

```r
expect_equal(count_queries(user_selects(session, "Gene", "HBB")), 2)
```

The user actions settle the page as the browser would, so the count covers
everything the action sets off, including the dropdowns that refresh after it.

The count comes from `db.R`, which wraps the RPostgres driver's
`dbSendQuery()`, so it sees `dbGetQuery()` and `dbExecute()` calls wherever
they are issued. The counter is per process, so take differences (as
`count_queries()` does) rather than reading the total.
`tests/testthat/test-query-count.R` holds the budgets. When an optimisation
lowers a count, lower its budget to lock the gain in.

## Artificial database latency

To feel the remote round-trip cost while running the app locally, set
`SPLICEVAULT_DB_LATENCY_MS` to a delay in milliseconds added before every
query:

```bash
SPLICEVAULT_DB_LATENCY_MS=150 ./launch.sh
```

or put `SPLICEVAULT_DB_LATENCY_MS=150` in `.env`. The app logs a warning at
start-up while it is on. It is off when unset or empty, which is how CI and
both deploys run: nothing sets it there. An invalid value stops the app at
start-up.

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
`config.yml` profile. Rerun the tests after reseeding, and review the snapshot changes with
`./run_tests.sh --update-snapshots` and `git diff`.
