# Database access: the app's connection pool, plus instrumentation (a query
# counter for tests and opt-in artificial latency for local runs). Usage of the
# instrumentation is documented in tests/README.md.
#
# The instrumentation lives on the RPostgres driver, so queries are seen
# wherever they are issued: dbGetQuery() and dbExecute() both go through
# dbSendQuery(), and the pool opens its connections through
# instrumented_postgres().

db_instrumentation <- new.env()
db_instrumentation$queries <- 0L
db_instrumentation$validating <- FALSE

# Queries the app has issued so far in this R process. The setup statements
# RPostgres runs inside dbConnect() (date style, time zone, type map) are
# deliberately left out: they are driver overhead per connection, not app
# queries, and counting them would make budgets depend on when a connection
# opens. So are the pool's validation queries (see onValidate below), which
# depend on how long a connection has sat idle. Tests take differences of it
# (see count_queries() in tests/testthat/helper-app.R).
db_query_count <- function() db_instrumentation$queries

# Artificial delay per query, in seconds, from SPLICEVAULT_DB_LATENCY_MS.
# Unset or empty means no delay, which is how CI and deploys run.
db_latency_seconds <- function() {
  raw <- Sys.getenv("SPLICEVAULT_DB_LATENCY_MS")
  if (raw == "") return(0)
  ms <- suppressWarnings(as.numeric(raw))
  if (is.na(ms) || ms < 0) {
    stop("SPLICEVAULT_DB_LATENCY_MS must be a number of milliseconds >= 0, not '", raw, "'")
  }
  ms / 1000
}

# The app does not attach RPostgres, so its classes are looked up in its namespace.
rpostgres_class <- function(name) getClass(name, where = asNamespace("RPostgres"))
setClass("InstrumentedPqDriver", contains = rpostgres_class("PqDriver"))
setClass("InstrumentedPqConnection", contains = rpostgres_class("PqConnection"))

setMethod("dbConnect", "InstrumentedPqDriver", function(drv, ...) {
  new("InstrumentedPqConnection", callNextMethod())
})

setMethod("dbSendQuery", "InstrumentedPqConnection", function(conn, statement, ...) {
  if (!db_instrumentation$validating) {
    db_instrumentation$queries <- db_instrumentation$queries + 1L
  }
  latency <- db_latency_seconds()
  if (latency > 0) Sys.sleep(latency)
  callNextMethod()
})

# Drop-in for RPostgres::Postgres().
instrumented_postgres <- function() {
  new("InstrumentedPqDriver", RPostgres::Postgres())
}

# The pool checks a connection with a query before lending it out (when it
# has not checked it in the last validationInterval seconds). These checks
# still pay the artificial latency, as they would the real round trip, but are
# not counted as app queries.
setMethod("onValidate", "InstrumentedPqConnection", function(object, query) {
  db_instrumentation$validating <- TRUE
  on.exit(db_instrumentation$validating <- FALSE)
  callNextMethod()
})

# The app's database connection: a pool that validates a connection before
# lending it out, so a connection the server dropped while the app sat idle is
# replaced rather than handed to a query. One connection is kept open; the
# app's single R thread rarely needs more. conn_args is the `dataconnection`
# entry of a config profile, which also sets:
# - validation_interval: seconds a validated connection is trusted before it
#   is checked again
# - idle_timeout: seconds an extra connection may sit unused before it is
#   closed. The pool schedules this on Shiny's event loop each time a
#   connection is returned, and shiny::testServer() waits for that loop to
#   empty before reading an output, so the test profile sets it to 0.
# Connections are tagged application_name = 'splicevault' so they can be found
# in pg_stat_activity.
open_db_pool <- function(conn_args) {
  seconds <- function(name) {
    value <- conn_args[[name]]
    if (!is.numeric(value) || length(value) != 1 || is.na(value) || value < 0) {
      stop("dataconnection: ", name, " must be a number of seconds >= 0")
    }
    value
  }
  dbPool(instrumented_postgres(),
         dbname = conn_args$dbname,
         host = conn_args$host,
         port = conn_args$port,
         user = conn_args$user,
         password = conn_args$password,
         application_name = "splicevault",
         minSize = 1,
         maxSize = 5,
         idleTimeout = seconds("idle_timeout"),
         validationInterval = seconds("validation_interval"))
}

# Closes the pool's connections. Safe to call more than once.
close_db_pool <- function(pool) {
  if (DBI::dbIsValid(pool)) poolClose(pool)
  invisible()
}
