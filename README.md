# SpliceVault-40K

SpliceVault-40K is a web portal to access 40K-RNA (hg19), which quantifies natural variation in splicing and potently predicts the nature of variant-associated mis-splicing. Users require no bioinformatics expertise and can retrieve stochastic mis-splicing events for any splice-junction annotated in Ensembl or RefSeq.

Default settings display 40K-RNA Top-4 output according to the optimised parameters we describe herein, with the option to customise the number of events returned, and distance scanned for cryptic splice-sites.

We highly recommend reading ***Dawes et al. 2022 Empirical prediction of variant-activated cryptic splice donors using population-based RNA-Seq data*** to gain a better understanding of the data and stats behind SpliceVault-40K.

## Online portal

SpliceVault-40K is hosted at https://kidsneuro.shinyapps.io/splicevault/

## What was this developed on
* R 4.1+
* Hosted on https://www.shinyapps.io/
* Refer to `dependencies.R` for list of packages that are required for SpliceVault to operate properly

## Local installation of SpliceVault

Whilst not geared towards self-hosting, it is possible to install SpliceVault locally on your server/desktop/laptop for development. This requires a few key steps

1. Postgresql v13 database hosting splicing events. (Note: An [SQL script](https://github.com/kidsneuro-lab/SpliceVault/wiki/SQL-script-to-create-missplicing-database) has been provided on the Wiki for convenience)
   Note: You may use [dockerised postgres](https://hub.docker.com/_/postgres) or [postgres app](https://postgresapp.com/) (if on a Mac)

2. Splicing events datasets to load into the database (see below) and loaded using `psql`
3. Set up [config.yml](https://github.com/kidsneuro-lab/SpliceVault/wiki/config.yml-syntax)
2. Shiny app navigating Missplicing events (this repository). This is purely a database frontend that makes it easy to navigate Splice junction datasets. This has been primarily designed with https://www.shinyapps.io/ and running this locally may require installation of additional dependencies

## Download Source Data 

300K-RNA and 40K-RNA are available at the following links:

https://storage.googleapis.com/misspl-db-data/misspl_events_300k_hg38.sql.gz
https://storage.googleapis.com/misspl-db-data/misspl_events_40k_hg19.sql.gz

The files are stored in google storage and are set to 'requester pays'. Please ensure you have a billing project.
