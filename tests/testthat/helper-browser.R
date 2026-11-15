# Shared setup for the browser tests (test-browser-*.R): the app runs in its
# own R process on the fixture database and is driven through headless Chrome
# with shinytest2. See "Browser tests" in tests/README.md.

# Seconds to wait for the app to load and for each step, from
# SPLICEVAULT_BROWSER_TIMEOUT_MS. Chrome runs emulated on Apple Silicon, so the
# default is generous.
browser_timeout_ms <- function() {
  raw <- Sys.getenv("SPLICEVAULT_BROWSER_TIMEOUT_MS", "60000")
  ms <- suppressWarnings(as.numeric(raw))
  if (is.na(ms) || ms <= 0) {
    stop("SPLICEVAULT_BROWSER_TIMEOUT_MS must be a number of milliseconds > 0, not '", raw, "'")
  }
  ms
}

# A copy of the app to run, made once per test run. The repository is mounted
# read-only in the test container and google-analytics.html is generated
# outside it (launch.sh, deploys), so the copy gets its template instead.
.browser <- new.env()
browser_app_dir <- function() {
  if (is.null(.browser$dir)) {
    dir <- file.path(tempdir(), "splicevault-app")
    dir.create(dir, showWarnings = FALSE)
    files <- c("ui.R", "server.R", "global.R", "helpers.R", "db.R",
               "dependencies.R", "help.csv", "faq.html", "www")
    file.copy(file.path(app_dir(), files), dir, recursive = TRUE)
    file.copy(file.path(app_dir(), "google-analytics-template.html"),
              file.path(dir, "google-analytics.html"))
    .browser$dir <- dir
  }
  .browser$dir
}

# Starts the app on the fixture database and opens it in headless Chrome.
# Stops both when the calling test finishes. wait = FALSE returns as soon as
# the page has loaded, without waiting for the server to fill the dropdowns.
# latency_ms is passed to the app as SPLICEVAULT_DB_LATENCY_MS.
local_browser_app <- function(wait = TRUE, latency_ms = NULL, env = parent.frame()) {
  vars <- c(R_CONFIG_FILE = file.path(app_dir(), "config-template.yml"),
            R_CONFIG_ACTIVE = "test")
  if (!is.null(latency_ms)) vars["SPLICEVAULT_DB_LATENCY_MS"] <- as.character(latency_ms)
  # The app's R process inherits these from this one.
  withr::local_envvar(vars, .local_envir = env)
  timeout <- browser_timeout_ms()
  app <- shinytest2::AppDriver$new(
    browser_app_dir(),
    name = "splicevault",
    load_timeout = timeout,
    timeout = timeout,
    wait = wait
  )
  withr::defer(app$stop(), envir = env)
  app
}

# Evaluates JavaScript in the page and returns its value.
in_page <- function(app, js) app$get_js(js)

# Waits until a JavaScript expression is true in the page.
wait_until <- function(app, js) app$wait_for_js(js, timeout = browser_timeout_ms())

# ---------------------------------------------------------------------------
# The user's view of the page. Scenarios use only the functions below, naming
# fields and buttons by their labels on screen and options by the text the
# user sees, as in helper-app.R. Input IDs and CSS selectors stay in this file.
# ---------------------------------------------------------------------------

# Opens the app and waits for the dropdowns to fill.
browser_opens_app <- function() {
  app <- local_browser_app(env = parent.frame())
  wait_for_dropdowns(app)
  app
}

# Picks an option, by the text the user sees, in a dropdown, tab or radio
# button. Dropdowns are server-side selectize inputs, which load their options
# as the user types, so this types the option's text, waits for it to load and
# picks it.
browser_selects <- function(app, field, option) {
  if (field %in% names(choice_ids)) {
    do.call(app$set_inputs, stats::setNames(list(option), choice_ids[[field]]))
    wait_for_dropdowns(app)
    return(invisible(app))
  }
  id <- field_id(field, dropdown_ids)
  selectize <- sprintf("$('#%s')[0].selectize", id)
  label <- jsonlite::toJSON(option, auto_unbox = TRUE)
  find_option <- sprintf("Object.values(%s.options).find(o => o.label === %s)", selectize, label)
  in_page(app, sprintf("%s.onSearchChange(%s)", selectize, label))
  wait_until(app, sprintf("%s !== undefined", find_option))
  in_page(app, sprintf("%s.setValue(%s.value)", selectize, find_option))
  wait_for_dropdowns(app)
  invisible(app)
}

# Waits until the server has finished and the gene, transcript and exon
# dropdowns all show a selection again. Shiny being idle is not enough: each
# server update empties a dropdown and the page then fetches its options and
# selection in a separate request.
wait_for_dropdowns <- function(app) {
  app$wait_for_idle()
  filled <- vapply(c("geneInput", "txInput", "exonInput"), function(id) {
    sprintf("$('#%s')[0].selectize.getValue() !== ''", id)
  }, character(1))
  wait_until(app, paste(filled, collapse = " && "))
  app$wait_for_idle()
}

# Empties a dropdown, as when the user deletes its selection.
browser_clears <- function(app, field) {
  in_page(app, sprintf("$('#%s')[0].selectize.clear()", field_id(field, dropdown_ids)))
  app$wait_for_idle()
  invisible(app)
}

# Ticks or unticks a checkbox in the sidebar.
browser_changes <- function(app, setting, value) {
  do.call(app$set_inputs, stats::setNames(list(value), field_id(setting, setting_ids)))
  invisible(app)
}

# Clicks Generate Table and waits for the events table to be drawn. DT draws
# a new table element each time, so any table already on the page is marked
# first and the wait is for one without the mark.
browser_generates_table <- function(app) {
  in_page(app, "$('#table_ms table').addClass('drawn-before-click')")
  app$click(button_ids[["Generate Table"]])
  app$wait_for_idle()
  wait_until(app, "$('#table_ms table.dataTable:not(.drawn-before-click)').length > 0")
  invisible(app)
}

# Whether a button is greyed out.
button_disabled <- function(app, button) {
  in_page(app, sprintf("$('#%s').is(':disabled')", field_id(button, button_ids)))
}

# Checks that a button becomes greyed out (state = "disabled") or clickable
# ("enabled"), waiting for it.
expect_button <- function(app, button, state) {
  js <- sprintf("$('#%s').is(':disabled')", field_id(button, button_ids))
  wait_until(app, if (state == "disabled") js else paste0("!", js))
  testthat::expect_equal(if (button_disabled(app, button)) "disabled" else "enabled", state,
                         label = paste(button, "state"))
}

# The events table as the browser shows it: column headers, the rows drawn on
# the current page and the rows across every page.
shown_table <- function(app) {
  table <- "$('#table_ms table.dataTable').DataTable()"
  list(
    headers = unlist(in_page(app, sprintf(
      "%s.columns().header().toArray().map(h => h.textContent)", table))),
    rows_on_page = in_page(app, "$('#table_ms table.dataTable tbody tr').length"),
    rows = in_page(app, sprintf("%s.rows().count()", table))
  )
}

# ---------------------------------------------------------------------------
# Exports. DT's Buttons extension builds the files in the browser, so they
# never pass through Shiny and shinytest2's get_download() cannot see them.
# Chrome saves them to a download directory instead.
# ---------------------------------------------------------------------------

export_buttons <- c("Copy" = ".buttons-copy", "Excel" = ".buttons-excel",
                    "CSV" = ".buttons-csv", "PDF" = ".buttons-pdf")
export_files <- c("Excel" = "xlsx", "CSV" = "csv", "PDF" = "pdf")

# Opens the Download menu, unless it is already open (it stays open after a
# download).
open_download_menu <- function(app) {
  in_page(app, "if ($('.dt-button-collection:visible').length === 0) $('#table_ms .buttons-collection').click()")
  wait_until(app, "$('.dt-button-collection:visible').length > 0")
}

# Labels of the export buttons: those above the table, then those in the
# Download menu.
export_labels <- function(app) {
  labels <- function(selector) {
    # Without the arrow DT adds to the Download button.
    unlist(in_page(app, sprintf(
      "$('%s').toArray().map(b => $(b).clone().find('.dt-button-down-arrow').remove().end().text().trim())",
      selector)))
  }
  above <- labels("#table_ms .dt-buttons > .dt-button")
  open_download_menu(app)
  c(above, labels(".dt-button-collection .dt-button"))
}

# Lets Chrome save downloads, into a fresh directory that is removed when the
# calling test finishes. Returns the directory.
local_downloads <- function(app, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  app$get_chromote_session()$Browser$setDownloadBehavior(behavior = "allow", downloadPath = dir)
  dir
}

# Clicks an export button (opening the Download menu first for Excel, CSV and
# PDF) and returns the file Chrome saved, once it is complete.
browser_downloads <- function(app, format, dir) {
  open_download_menu(app)
  in_page(app, sprintf("$('.dt-button-collection %s').click()", export_buttons[[format]]))
  pattern <- paste0("\\.", export_files[[format]], "$")
  deadline <- Sys.time() + browser_timeout_ms() / 1000
  repeat {
    found <- list.files(dir, pattern = pattern, full.names = TRUE)
    if (length(found) == 1 && file.size(found) > 0) return(found)
    if (Sys.time() > deadline) stop("no complete ", format, " download in ", dir)
    Sys.sleep(0.2)
  }
}

# Clicks Copy and returns the lines of text it copies. Headless Chrome has no
# clipboard, so DT falls back to its "Press ctrl or ⌘ + C" notice, which holds
# the copied text in a text box for the user to copy by hand; this reads it
# from there.
browser_copies <- function(app) {
  in_page(app, sprintf("$('%s').click()", export_buttons[["Copy"]]))
  wait_until(app, "$('.dt-button-info textarea').length > 0")
  text <- in_page(app, "$('.dt-button-info textarea').val()")
  in_page(app, "$('.dt-button-info').click()")  # closes the notice
  strsplit(text, "\n", fixed = TRUE)[[1]]
}

# Rows of copied text below the header row: DT copies the page title, a blank
# line, the headers and then one line per row, separated by tabs.
copied_rows <- function(lines, headers) {
  header_line <- match(paste(headers, collapse = "\t"), lines)
  if (is.na(header_line)) return(NULL)
  rows <- lines[-seq_len(header_line)]
  rows[nzchar(rows)]
}

# Header and data rows of a CSV export. DT writes every row on every page,
# with no newline after the last.
read_csv_export <- function(path) {
  utils::read.csv(text = readLines(path, warn = FALSE), check.names = FALSE,
                  colClasses = "character")
}

# Checks that every export works for the table on screen: Copy and the CSV
# have the table's headers and every row, and the Excel and PDF files are not
# empty.
expect_exports_work <- function(app) {
  shown <- shown_table(app)
  testthat::expect_equal(export_labels(app), c("Copy", "Download", "Excel", "CSV", "PDF"))
  copied <- copied_rows(browser_copies(app), shown$headers)
  testthat::expect_false(is.null(copied), label = "copied text has no header row")
  testthat::expect_length(copied, shown$rows)

  dir <- local_downloads(app)
  csv <- read_csv_export(browser_downloads(app, "CSV", dir))
  testthat::expect_equal(names(csv), shown$headers, label = "CSV headers")
  testthat::expect_equal(nrow(csv), shown$rows, label = "CSV rows")
  for (format in c("Excel", "PDF")) {
    file <- browser_downloads(app, format, dir)
    testthat::expect_gt(file.size(file), 0, label = paste(format, "file size"))
  }
}
