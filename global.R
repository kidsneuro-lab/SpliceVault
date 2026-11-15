source('dependencies.R')
source('db.R')

flog.threshold("INFO")
layout <- layout.format('[~l] [~t] [~n.~f] ~m')
flog.layout(layout)

# DATA TRANSFORMATION AND NEW VARIABLES -----------------------------------
#Sys.setenv(R_CONFIG_ACTIVE = "local")
conn_args <- config::get("dataconnection")
latency <- db_latency_seconds()  # also fails fast on an invalid value
if (latency > 0) {
  flog.warn("Adding %s ms of artificial latency to every database query (SPLICEVAULT_DB_LATENCY_MS)",
            latency * 1000)
}
# A pool (see open_db_pool() in db.R), used like a connection: queries through
# con check out a validated connection and return it.
con <- open_db_pool(conn_args)
local({
  pool <- con
  onStop(function() close_db_pool(pool))
})

steps <- fread("help.csv")
