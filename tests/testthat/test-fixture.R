# Guards the fixture database contract: every case the app tests rely on must
# be present after a reseed (tests/fixture/seed.sh).

fixture_query <- function(sql) {
  local_test_app()
  args <- config::get("dataconnection")
  con <- DBI::dbConnect(RPostgres::Postgres(), dbname = args$dbname, host = args$host,
                        port = args$port, user = args$user, password = args$password)
  on.exit(DBI::dbDisconnect(con))
  DBI::dbGetQuery(con, sql)
}

tx_tables <- c("300K-RNA (hg38)" = "SELECT gene_name, transcript_type, strand, canonical::int AS canonical FROM misspl_app.ref_tx",
               "40K-RNA (hg19)"  = "SELECT gene_name, transcript_type, strand, canonical FROM misspl_app.misspl_events_40k_hg19_tx")

for (db in names(tx_tables)) {
  test_that(paste("fixture covers genes, transcript types, canonical flags and strands for", db), {
    tx <- fixture_query(tx_tables[[db]])

    expect_setequal(unique(tx$gene_name), fixture_genes)
    for (type in c("refseq", "ensembl")) {
      of_type <- tx[tx$transcript_type == type, ]
      expect_setequal(unique(of_type$gene_name), fixture_genes)
      expect_setequal(unique(of_type$canonical), c(0, 1))
    }
    expect_setequal(unique(tx$strand), c("+", "-"))
  })
}

# "Show all events" pages the table 11 rows at a time (server.R pageLength).
show_all_page_length <- 11

test_that("fixture has a splice site with more events than one table page", {
  per_ss_300k <- fixture_query("SELECT ss_id, COUNT(*) AS n FROM misspl_app.missplicing_stats GROUP BY ss_id")
  per_ss_40k <- fixture_query("SELECT gene_tx_id, ss_type, exon_no, COUNT(*) AS n
                                 FROM misspl_app.misspl_events_40k_hg19_events
                                GROUP BY 1, 2, 3")
  expect_gt(max(per_ss_300k$n), show_all_page_length)
  expect_gt(max(per_ss_40k$n), show_all_page_length)
})

test_that("fixture has a splice site with no events in a tissue", {
  empty <- fixture_query(
    "SELECT ms.ss_id, rt.tissue_id
       FROM (SELECT DISTINCT ss_id FROM misspl_app.missplicing_stats) ms
      CROSS JOIN misspl_app.ref_tissues rt
      WHERE NOT EXISTS (
            SELECT 1 FROM misspl_app.missplicing_stats ms2
              JOIN misspl_app.tissue_missplicing_stats tms ON tms.misspl_stat_id = ms2.misspl_stat_id
             WHERE ms2.ss_id = ms.ss_id AND tms.tissue_id = rt.tissue_id)
      LIMIT 1")
  expect_equal(nrow(empty), 1)
})

test_that("fixture has events in every clinically accessible tissue", {
  tissues <- fixture_query(
    "SELECT rt.tissue_id, COUNT(tms.tissue_misspl_stat_id) AS n
       FROM misspl_app.ref_tissues rt
       LEFT JOIN misspl_app.tissue_missplicing_stats tms ON tms.tissue_id = rt.tissue_id
      WHERE rt.clinically_accessible
      GROUP BY rt.tissue_id")
  expect_setequal(tissues$tissue_id, c(4, 5, 6, 30))
  expect_true(all(tissues$n > 0))
})
