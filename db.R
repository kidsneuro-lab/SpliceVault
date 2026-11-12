# Database access instrumentation: a query counter for tests and opt-in
# artificial latency for local runs. Usage is documented in tests/README.md.
#
# Both live on the RPostgres driver, so queries are seen wherever they are
# issued: dbGetQuery() and dbExecute() both go through dbSendQuery(). A
# future connection pool should be built on instrumented_postgres() so that
# the connections it opens are instrumented too.

db_instrumentation <- new.env()
db_instrumentation$queries <- 0L

# Total queries run by this R process so far. Tests take differences of it
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
  db_instrumentation$queries <- db_instrumentation$queries + 1L
  latency <- db_latency_seconds()
  if (latency > 0) Sys.sleep(latency)
  callNextMethod()
})

# Drop-in for RPostgres::Postgres().
instrumented_postgres <- function() {
  new("InstrumentedPqDriver", RPostgres::Postgres())
}
