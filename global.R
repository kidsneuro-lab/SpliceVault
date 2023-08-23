source('dependencies.R')
flog.appender(appender.file("/var/log/shiny-server/splicevault.log"))
flog.threshold("TRACE")
layout <- layout.format('[~l] [~t] [~n.~f] ~m')
flog.layout(layout)

db <- config::get("db")
db_host <- db$host
db_name <- db$name
db_username <- db$username
db_password <- db$password
db_port <- db$port

flog.info("--------------------")
flog.info("Configuration:")
flog.info("--------------------")
flog.info("db_host %s", db_host)
flog.info("db_name %s", db_name)
flog.info("db_username %s", db_username)
flog.info("db_password %s", db_password)
flog.info("db_port %s", db_port)
flog.info("--------------------")

con <- dbConnect(RPostgres::Postgres(),
                 dbname = db_name,
                 host = db_host,
                 port = db_port,
                 user = db_username,
                 password = db_password
)

steps <- fread("help.csv")
