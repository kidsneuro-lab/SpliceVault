# Runs the test suite. Use ./run_tests.sh, which runs this inside the test
# container. An optional argument filters test files, e.g. "smoke".
filter <- commandArgs(trailingOnly = TRUE)[1]

testthat::test_dir(
  "tests/testthat",
  filter = if (is.na(filter)) NULL else filter,
  reporter = "progress",
  stop_on_failure = TRUE
)
