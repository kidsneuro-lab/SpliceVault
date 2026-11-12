# Artificial database latency (SPLICEVAULT_DB_LATENCY_MS), for feeling the
# round-trip cost of the remote database locally. See tests/README.md.

test_that("latency is off when SPLICEVAULT_DB_LATENCY_MS is unset", {
  withr::local_envvar(SPLICEVAULT_DB_LATENCY_MS = NA)
  with_app({
    expect_equal(db_latency_seconds(), 0)
  })
})

test_that("each query waits SPLICEVAULT_DB_LATENCY_MS milliseconds", {
  withr::local_envvar(SPLICEVAULT_DB_LATENCY_MS = "250")
  with_app({
    expect_equal(db_latency_seconds(), 0.25)

    elapsed <- system.time(for (i in 1:2) DBI::dbGetQuery(con, "SELECT 1"))[["elapsed"]]
    expect_gte(elapsed, 0.5)
  })
})

test_that("an invalid SPLICEVAULT_DB_LATENCY_MS is an error, not silently ignored", {
  with_app({
    for (bad in c("fast", "-5")) {
      withr::with_envvar(c(SPLICEVAULT_DB_LATENCY_MS = bad),
                         expect_error(db_latency_seconds(), "SPLICEVAULT_DB_LATENCY_MS"))
    }
  })
})
