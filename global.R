source('dependencies.R')

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

gene_names_40k_ensembl <- dbGetQuery(con,
                                     "SELECT DISTINCT gene_name FROM misspl_app.misspl_events_40k_hg19_tx
                            WHERE transcript_type='ensembl'
                            ORDER BY gene_name")
gene_names_40k_ensembl <- gene_names_40k_ensembl$gene_name
gene_names_40k_refseq <- dbGetQuery(con,
                                    "SELECT DISTINCT gene_name FROM misspl_app.misspl_events_40k_hg19_tx
                                            WHERE transcript_type='refseq'
                            ORDER BY gene_name")
gene_names_40k_refseq <- gene_names_40k_refseq$gene_name

steps <- fread("help.csv")
faq <- fread("faq.csv")
