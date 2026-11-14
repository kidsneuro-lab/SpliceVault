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
# - shinyjs enable/disable/toggleState calls, as "enable" or "disable" by
#   element id
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
    if (is.null(message$id)) return(invisible())
    state <- switch(type,
                    "shinyjs-enable" = "enable",
                    "shinyjs-disable" = "disable",
                    "shinyjs-toggleState" = if (isTRUE(message$condition)) "enable" else "disable",
                    NULL)
    if (!is.null(state)) session$browser$js[[message$id]] <- state
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

# The page as ui.R renders it, as HTML, built once per test run. Included
# HTML files are read as-is (shiny::includeHTML() warns that faq.html is a full
# document); google-analytics.html is generated outside the repository
# (launch.sh, deploys), so its template stands in when it is missing. Call it
# inside shiny::testServer(), where global.R has run.
.page <- new.env()
page_html <- function() {
  if (is.null(.page$html)) {
    env <- new.env(parent = globalenv())
    env$includeHTML <- function(path) {
      if (!file.exists(path)) path <- sub("\\.html$", "-template.html", path)
      htmltools::HTML(paste(readLines(path, warn = FALSE), collapse = "\n"))
    }
    eval(parse("ui.R"), envir = env)
    .page$html <- htmltools::renderTags(env$ui)$html
  }
  .page$html
}

# Input values the browser starts with, read from the rendered page: the
# active tab, sliders, checkboxes, radio buttons and the variant text box. The
# gene, transcript and exon dropdowns start empty.
page_defaults <- function(html = page_html()) {
  tags <- regmatches(html, gregexpr("<input[^>]*>", html))[[1]]
  attr_of <- function(tag, name) {
    m <- regmatches(tag, regexec(paste0(" ", name, '="([^"]*)"'), tag))[[1]]
    if (length(m)) m[2] else NA_character_
  }
  id_tag <- function(id) tags[grepl(paste0(' id="', id, '"'), tags)]
  checked_radio <- function(name) {
    radio <- tags[grepl(paste0(' name="', name, '"'), tags) & grepl(" checked=", tags)]
    attr_of(radio, "value")
  }
  tabset <- regmatches(html, regexpr('id="mode"[\\s\\S]*?</ul>', html, perl = TRUE))
  active_tab <- regmatches(tabset, regexec('class="active">\\s*<a [^>]*data-value="([^"]*)"', tabset))[[1]][2]

  out <- list(mode = active_tab, variant = attr_of(id_tag("variant"), "value"))
  for (id in c("dbInput", "txTypeInput", "ssTypeInput")) out[[id]] <- checked_radio(id)
  for (id in c("eventsNoInput", "esInput", "cssInput")) out[[id]] <- as.numeric(attr_of(id_tag(id), "data-from"))
  for (id in c("allevents", "allskips", "allcryptics")) out[[id]] <- grepl(" checked", id_tag(id))
  c(out, list(geneInput = "", txInput = "", exonInput = ""))
}

# Inputs as the browser sends them on first load. db and tx_type override the
# page defaults.
initial_inputs <- function(db = NULL, tx_type = NULL) {
  inputs <- page_defaults()
  if (!is.null(db)) inputs$dbInput <- db
  if (!is.null(tx_type)) inputs$txTypeInput <- tx_type
  inputs
}

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

# Runs test code inside shiny::testServer() for the app on the fixture
# database, with a recording session; the code sees `session`, `input` and
# `output` as the server function does.
with_app <- function(code) {
  local_test_app()
  shiny::testServer(app_dir(), {{ code }}, session = recording_session())
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

# ---------------------------------------------------------------------------
# The user's view of the form. Scenarios use only the functions below, naming
# fields, settings and buttons by their labels on screen and options by the
# text the user sees. Input IDs and database IDs stay in this file.
# ---------------------------------------------------------------------------

# Dropdowns whose options come from the database.
dropdown_ids <- c("Gene" = "geneInput", "Transcript" = "txInput",
                  "Exon" = "exonInput", "Tissue" = "tissuesInput")
# Tabs and radio buttons, whose option labels are also their values.
choice_ids <- c("Tab" = "mode", "Dataset" = "dbInput",
                "Transcript type" = "txTypeInput", "Splice site" = "ssTypeInput")
# Sidebar settings.
setting_ids <- c("Number of Events" = "eventsNoInput", "Show all Events" = "allevents",
                 "Maximum Number of Exons Skipped" = "esInput",
                 "Show all Exon Skipping" = "allskips",
                 "Show Cryptics Within" = "cssInput", "Show all Cryptics" = "allcryptics")
button_ids <- c("Generate Table" = "confirm", "Restore Settings" = "restore")

set_input <- function(session, id, value) {
  do.call(session$setInputs, stats::setNames(list(value), id))
}

field_id <- function(field, ids) {
  if (!field %in% names(ids)) stop("unknown field '", field, "'; expected one of: ", paste(names(ids), collapse = ", "))
  ids[[field]]
}

# Options (label, value) the user can see in a dropdown, or NULL when it is
# not shown.
dropdown_options <- function(session, field) {
  id <- field_id(field, dropdown_ids)
  if (id == "tissuesInput") return(tissue_options(session))
  dropdown(session, id)
}

# The label of the option shown as selected in a dropdown, tab or radio button.
selected_option <- function(session, field) {
  if (field %in% names(choice_ids)) return(shiny::isolate(session$input[[choice_ids[[field]]]]))
  options <- dropdown_options(session, field)
  value <- shiny::isolate(session$input[[field_id(field, dropdown_ids)]])
  options$label[options$value == value]
}

# The page has loaded with the defaults ui.R sets (the Variant tab showing),
# but the server has not yet filled the dropdowns.
app_starts_loading <- function(session) {
  do.call(session$setInputs, initial_inputs())
}

# Opens the app as a user would, and waits for the dropdowns to fill.
user_opens_app <- function(session) {
  app_starts_loading(session)
  settle(session)
}

# Picks an option, by the text the user sees, in a dropdown, tab or radio
# button.
user_selects <- function(session, field, option) {
  if (field %in% names(choice_ids)) {
    set_input(session, choice_ids[[field]], option)
  } else {
    options <- dropdown_options(session, field)
    if (!option %in% options$label) {
      stop(field, " has no option '", option, "'; it shows: ", paste(options$label, collapse = ", "))
    }
    value <- as.character(options$value[options$label == option])
    set_input(session, dropdown_ids[[field]], value)
  }
  settle(session)
}

# Empties a dropdown, as when the user deletes its selection.
user_clears <- function(session, field) {
  set_input(session, field_id(field, dropdown_ids), "")
  settle(session)
}

# Moves a slider or ticks/unticks a checkbox in the sidebar.
user_changes <- function(session, setting, value) {
  set_input(session, field_id(setting, setting_ids), value)
  settle(session)
}

# Clicks a button.
user_clicks <- function(session, button) {
  id <- field_id(button, button_ids)
  clicks <- (shiny::isolate(session$input[[id]]) %||% 0) + 1
  set_input(session, id, clicks)
  settle(session)
}

# Checks the options a dropdown shows, in order, and which one is selected.
expect_dropdown <- function(session, field, options, selected) {
  shown <- dropdown_options(session, field)
  testthat::expect_false(is.null(shown), label = paste(field, "dropdown is hidden"))
  testthat::expect_equal(shown$label, options, label = paste(field, "options"))
  expect_selected(session, field, selected)
}

# Checks which option a dropdown, tab or radio button shows as selected.
expect_selected <- function(session, field, selected) {
  testthat::expect_equal(selected_option(session, field), selected,
                         label = paste(field, "selection"))
}

# Checks that a dropdown is not shown at all.
expect_hidden <- function(session, field) {
  testthat::expect_null(dropdown_options(session, field), label = paste(field, "dropdown"))
}

# Checks a sidebar setting's value.
expect_setting <- function(session, setting, value) {
  testthat::expect_equal(shiny::isolate(session$input[[field_id(setting, setting_ids)]]), value,
                         label = setting)
}

# Checks whether a button or sidebar setting can be used or is greyed out.
expect_enabled <- function(session, control, enabled) {
  id <- field_id(control, c(button_ids, setting_ids))
  testthat::expect_equal(session$browser$js[[id]], if (enabled) "enable" else "disable",
                         label = paste(control, "state"))
}
