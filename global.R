source('dependencies.R')

flog.threshold("INFO")
layout <- layout.format('[~l] [~t] [~n.~f] ~m')
flog.layout(layout)

# DATA TRANSFORMATION AND NEW VARIABLES -----------------------------------
#Sys.setenv(R_CONFIG_ACTIVE = "local")
conn_args <- config::get("dataconnection")
con <- dbConnect(RPostgres::Postgres(),
                 dbname = conn_args$dbname,
                 host = conn_args$host,
                 port = conn_args$port,
                 user = conn_args$user,
                 password = conn_args$password
)

steps <- fread("help.csv")
