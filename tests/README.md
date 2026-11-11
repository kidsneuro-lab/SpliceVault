# Tests

The tests drive the Shiny server function through `shiny::testServer()`
against a small fixture database. The app reaches it through the `test`
profile in `config-template.yml`, so no real credentials are needed.

## Running the tests locally

Needs Docker and R with the project's renv library, plus testthat:

```bash
Rscript -e 'renv::install("testthat@3.3.2")'
```

Start the fixture database (PostgreSQL 13 on port 55432, loaded from
`tests/fixture/fixture.sql.gz`):

```bash
docker compose -f tests/fixture/docker-compose.yml up -d --wait
```

Run the suite from the repository root:

```bash
Rscript tests/testthat.R
```

Stop and remove the database when done (it reloads from the dump on next start):

```bash
docker compose -f tests/fixture/docker-compose.yml down
```

CI runs the same suite (`.github/workflows/test.yaml`) against a PostgreSQL
service container, and the test deployment waits for it to pass.

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
