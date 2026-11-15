# Time to first table: how long a user waits from the page loading to the
# events table being drawn, with artificial latency on every database query
# standing in for the round trip to the remote production database. Run it
# with ./run_tests.sh --benchmark, before and after a change that should make
# the dropdowns or the table faster, and compare the medians. It is not part
# of the test suite and CI does not run it: timings in the emulated test
# container vary too much to assert on.
#
# Each run starts a fresh app process and times two users in turn:
# - "first user": the first visitor after a start-up, with nothing cached
# - "second user": a second visitor to the same process
# Each user opens the page, switches to the Gene/Transcript/Exon tab, picks a
# gene and clicks Generate Table.
#
#   SPLICEVAULT_BENCHMARK_RUNS        runs (default 5)
#   SPLICEVAULT_BENCHMARK_LATENCY_MS  latency per query (default 100)

# shinytest2's AppDriver skips itself unless it knows it is not on CRAN.
Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages({
  library(testthat)
  library(shinytest2)
})
# The helpers resolve the app directory with test_path(), which needs to know
# it is running as a test: source_test_helpers() runs them from tests/testthat.
withr::with_envvar(c(TESTTHAT = "true"),
                   testthat::source_test_helpers("tests/testthat", env = globalenv()))

positive_number <- function(var, default) {
  raw <- Sys.getenv(var, default)
  value <- suppressWarnings(as.numeric(raw))
  if (is.na(value) || value <= 0) stop(var, " must be a number > 0, not '", raw, "'")
  value
}
runs <- positive_number("SPLICEVAULT_BENCHMARK_RUNS", "5")
latency_ms <- positive_number("SPLICEVAULT_BENCHMARK_LATENCY_MS", "100")

# One user's visit, timed from the page having loaded (the server session has
# started) to the table being drawn. Returns seconds.
time_visit <- function(app) {
  started <- Sys.time()
  wait_for_dropdowns(app)
  browser_selects(app, "Tab", "Gene/Transcript/Exon")
  browser_selects(app, "Gene", "SMN1")
  browser_generates_table(app)
  as.numeric(difftime(Sys.time(), started, units = "secs"))
}

# One fresh app process, visited by two users in turn.
time_run <- function(run) {
  first <- local_browser_app(wait = FALSE, latency_ms = latency_ms)
  first_seconds <- time_visit(first)
  second <- shinytest2::AppDriver$new(first$get_url(), name = "splicevault-second",
                                      load_timeout = browser_timeout_ms(),
                                      timeout = browser_timeout_ms(), wait = FALSE)
  on.exit(second$stop(), add = TRUE)
  second_seconds <- time_visit(second)
  message(sprintf("run %d: first user %.2f s, second user %.2f s",
                  run, first_seconds, second_seconds))
  data.frame(run = run, user = c("first user", "second user"),
             seconds = c(first_seconds, second_seconds))
}

timings <- do.call(rbind, lapply(seq_len(runs), time_run))

cat(sprintf("\nTime to first table, %d runs, %g ms latency per query (git %s)\n",
            runs, latency_ms,
            tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                     error = function(e) "unknown", warning = function(w) "unknown")))
for (user in unique(timings$user)) {
  seconds <- timings$seconds[timings$user == user]
  cat(sprintf("  %-12s median %.2f s (min %.2f, max %.2f)\n",
              user, stats::median(seconds), min(seconds), max(seconds)))
}
