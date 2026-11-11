# Shared setup for tests that drive the Shiny server function against the
# fixture database (tests/fixture). Start the database first:
#   docker compose -f tests/fixture/docker-compose.yml up -d --wait

# Resolved once at load time, before any test changes the working directory.
.app_dir <- normalizePath(testthat::test_path("..", ".."))
app_dir <- function() .app_dir

# Genes seeded into the fixture (see tests/fixture/seed_fixture.R).
fixture_genes <- c("CNN2", "HBA1", "HBB", "INS", "SMN1")

# Points the app at the fixture database through the `test` config profile and
# runs it from the app directory, as shiny::runApp() would. Closes the
# connection that global.R opens when the calling test finishes.
local_test_app <- function(env = parent.frame()) {
  withr::local_envvar(
    R_CONFIG_FILE = file.path(app_dir(), "config-template.yml"),
    R_CONFIG_ACTIVE = "test",
    .local_envir = env
  )
  withr::local_dir(app_dir(), .local_envir = env)
  withr::defer({
    if (exists("con", envir = globalenv())) {
      try(DBI::dbDisconnect(get("con", envir = globalenv())), silent = TRUE)
      rm("con", envir = globalenv())
    }
  }, envir = env)
  invisible(app_dir())
}

# A mock session that remembers what server-side selectize updates would send
# to the browser, so tests can check the choices a user would see. Shiny's
# mock session makes registerDataObj() a no-op; this records its data instead.
recording_session <- function() {
  session <- shiny::MockShinySession$new()
  session$dropdowns <- new.env()
  session$registerDataObj <- function(name, data, filterFunc) {
    assign(name, data, envir = session$dropdowns)
    invisible(paste0("session/mock/dataobj/", name))
  }
  session
}

# Choices (label, value) last sent for a server-side selectize input, with the
# selected value as the "selected" attribute.
dropdown <- function(session, inputId) {
  data <- get0(inputId, envir = session$dropdowns, inherits = FALSE)
  if (is.null(data)) return(NULL)
  out <- data.frame(label = data$label, value = unname(data$value), stringsAsFactors = FALSE)
  attr(out, "selected") <- unname(attr(data, "selected_value"))
  out
}

# Inputs as the browser sends them on first load in Gene/Transcript/Exon mode.
initial_inputs <- function(db = "300K-RNA (hg38)", tx_type = "RefSeq") {
  list(mode = "Gene/Transcript/Exon", dbInput = db, txTypeInput = tx_type,
       ssTypeInput = "Acceptor", geneInput = "", txInput = "", exonInput = "")
}
