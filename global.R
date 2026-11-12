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
con <- dbConnect(instrumented_postgres(),
                 dbname = conn_args$dbname,
                 host = conn_args$host,
                 port = conn_args$port,
                 user = conn_args$user,
                 password = conn_args$password
)

steps <- fread("help.csv")
