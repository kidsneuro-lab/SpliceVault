# Shared setup for tests that drive the Shiny server function against the
# fixture database (tests/fixture). Run them with ./run_tests.sh.

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

# A mock session that records what the server sends to the browser, so tests
# can check what a user would see:
# - choices for server-side selectize inputs (Shiny's mock session makes
#   registerDataObj() a no-op; this keeps the data instead)
# - input updates (new selected values) not yet applied by settle()
# - shinyjs enable/disable calls, by element id
# - how many times the tissue dropdown has been (re)defined, since the server
#   re-renders it with identical HTML and the browser still rebinds it
recording_session <- function() {
  session <- shiny::MockShinySession$new()
  session$dropdowns <- new.env()
  session$browser <- new.env()
  session$browser$pending <- list()
  session$browser$js <- list()
  session$browser$tissue_renders <- 0
  session$browser$tissue_renders_seen <- 0
  define_output <- session$defineOutput
  unlockBinding("defineOutput", session)
  session$defineOutput <- function(name, ...) {
    if (name == "tissuesInputUI") {
      session$browser$tissue_renders <- session$browser$tissue_renders + 1
    }
    define_output(name, ...)
  }
  session$registerDataObj <- function(name, data, filterFunc) {
    assign(name, data, envir = session$dropdowns)
    invisible(paste0("session/mock/dataobj/", name))
  }
  session$sendInputMessage <- function(inputId, message) {
    if (!is.null(message$value)) {
      session$browser$pending[[inputId]] <- message$value
    }
    invisible()
  }
  session$sendCustomMessage <- function(type, message) {
    if (type %in% c("shinyjs-enable", "shinyjs-disable") && !is.null(message$id)) {
      session$browser$js[[message$id]] <- sub("^shinyjs-", "", type)
    }
    invisible()
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
  c(list(mode = "Gene/Transcript/Exon", dbInput = db, txTypeInput = tx_type,
         ssTypeInput = "Acceptor", geneInput = "", txInput = "", exonInput = ""),
    default_settings)
}

# Sidebar settings as ui.R first renders them (tissuesInput aside, which only
# exists once its dropdown renders).
default_settings <- list(eventsNoInput = 4, allevents = FALSE, esInput = 2,
                         allskips = FALSE, cssInput = 600, allcryptics = FALSE)

# Inputs whose values the browser sends as strings, and sliders, whose values
# the server sends as strings (updateSliderInput) but the browser sends as numbers.
selectize_inputs <- c("geneInput", "txInput", "exonInput", "tissuesInput")
slider_inputs <- c("eventsNoInput", "esInput", "cssInput")

# Plays the browser's side of the conversation until nothing changes: applies
# every value the server sent to an input, and the selected tissue whenever the
# tissue dropdown is (re)rendered, as one batch per round, the way the browser
# reports changed inputs. Like the browser, it drops updates to the tissue
# dropdown while none is shown. Call it inside shiny::testServer() after
# setInputs().
settle <- function(session, max_rounds = 10) {
  for (round in seq_len(max_rounds)) {
    sent <- session$browser$pending
    session$browser$pending <- list()

    tissues <- tissue_options(session)
    if (is.null(tissues)) sent$tissuesInput <- NULL
    if (session$browser$tissue_renders != session$browser$tissue_renders_seen) {
      session$browser$tissue_renders_seen <- session$browser$tissue_renders
      if (!is.null(tissues)) sent$tissuesInput <- attr(tissues, "selected")
    }

    changes <- list()
    for (id in names(sent)) {
      value <- sent[[id]]
      if (id %in% selectize_inputs) value <- as.character(value)
      if (id %in% slider_inputs) value <- as.numeric(value)
      if (!identical(value, shiny::isolate(session$input[[id]]))) changes[[id]] <- value
    }
    if (length(changes) == 0) return(invisible(session))
    do.call(session$setInputs, changes)
  }
  stop("inputs still changing after ", max_rounds, " rounds")
}

# Sets inputs as a user would, then lets the browser catch up.
user_sets <- function(session, ...) {
  session$setInputs(...)
  settle(session)
}

# Runs test code inside shiny::testServer() for the app on the fixture
# database, with a recording session; the code sees `session`, `input` and
# `output` as the server function does.
with_app <- function(code) {
  local_test_app()
  shiny::testServer(app_dir(), {{ code }}, session = recording_session())
}

# Opens the app in Gene/Transcript/Exon mode and waits for the dropdowns to fill.
open_app <- function(session, db = "300K-RNA (hg38)", tx_type = "RefSeq") {
  do.call(session$setInputs, initial_inputs(db = db, tx_type = tx_type))
  settle(session)
}

# Label of the option currently selected in a server-side selectize input.
selected_label <- function(session, inputId) {
  choices <- dropdown(session, inputId)
  choices$label[choices$value == shiny::isolate(session$input[[inputId]])]
}

# Value of the option whose label starts with the given exon number.
exon_value <- function(session, exon_no) {
  exons <- dropdown(session, "exonInput")
  as.character(exons$value[exon_numbers(exons$label) == exon_no])
}

# First word of dropdown labels: the exon number in "3 (g.5227071)", the
# transcript ID in "NM_000518 (Canonical)".
label_key <- function(labels) sub(" .*", "", labels)
exon_numbers <- function(labels) as.integer(label_key(labels))

# Value of the transcript whose label starts with the given transcript ID.
tx_value <- function(session, tx_id) {
  txs <- dropdown(session, "txInput")
  as.character(txs$value[label_key(txs$label) == tx_id])
}

# Options (label, value) of the rendered tissue dropdown, with the selected
# value as the "selected" attribute, or NULL when no dropdown is shown.
tissue_options <- function(session) {
  ui <- session$getOutput("tissuesInputUI")
  if (is.null(ui) || is.null(ui$html)) return(NULL)
  html <- as.character(ui$html)
  options <- regmatches(html, gregexpr('<option value="[^"]*"( selected)?>[^<]*</option>', html))[[1]]
  out <- data.frame(label = sub('.*>([^<]*)</option>', "\\1", options),
                    value = sub('<option value="([^"]*)".*', "\\1", options),
                    stringsAsFactors = FALSE)
  attr(out, "selected") <- out$value[grepl(" selected>", options)]
  out
}

# "enable" or "disable": the last shinyjs state the server set for an element.
js_state <- function(session, id) session$browser$js[[id]]
