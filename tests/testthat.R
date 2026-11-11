# Runs the test suite from the repository root:
#   docker compose -f tests/fixture/docker-compose.yml up -d --wait
#   Rscript tests/testthat.R
testthat::test_dir(
  file.path(if (basename(getwd()) == "tests") ".." else ".", "tests", "testthat"),
  reporter = "progress",
  stop_on_failure = TRUE
)
