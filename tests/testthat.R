# Runs the test suite. Use ./run_tests.sh, which runs this inside the test
# container. An optional argument filters test files, e.g. "smoke".
filter <- commandArgs(trailingOnly = TRUE)[1]
filter <- if (is.na(filter)) NULL else filter

# testthat skips snapshot tests unless it knows it is not running on CRAN.
Sys.setenv(NOT_CRAN = "true")

if (identical(Sys.getenv("UPDATE_SNAPSHOTS"), "true")) {
  # Record snapshots, then accept every change so it shows up in git diff.
  testthat::test_dir("tests/testthat", filter = filter, reporter = "summary",
                     stop_on_failure = FALSE)
  testthat::snapshot_accept(path = "tests/testthat")
  message("Snapshots updated. Review them with git diff, then run ./run_tests.sh.")
} else {
  testthat::test_dir(
    "tests/testthat",
    filter = filter,
    reporter = "progress",
    stop_on_failure = TRUE
  )
}
