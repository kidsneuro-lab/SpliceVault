# SpliceVault

SpliceVault is a web portal to access 300K-RNA (hg38) and 40K-RNA (hg19), which quantifies natural variation in splicing and potently predicts the nature of variant-associated mis-splicing. Users require no bioinformatics expertise and can retrieve stochastic mis-splicing events for any splice-junction annotated in Ensembl or RefSeq.

Default settings display 300K-RNA Top-4 output according to the optimised parameters we describe herein, with the option to customise the number of events returned, distance scanned for cryptic splice-sites, and maximum number of exons skipped.

Our recommendation for application of PVS1 for essential splice-site variants is theorized consideration of the 300K-RNA Top-4: a feasible, evidence-based method to reliably assess for probable cryptic activation within a larger distance window of 600 nt.

We highly recommend reading ***Dawes et al, Nature Genetics 2023 https://www.nature.com/articles/s41588-022-01293-8 SpliceVault: predicting the precise nature of variant-associated mis-splicing*** to gain a better understanding of the data and stats behind SpliceVault.

Please cite Dawes et al, Nature Genetics 2023 https://www.nature.com/articles/s41588-022-01293-8 if you use the SpliceVault web portal or VEP plugin in your research.

## Online portal

SpliceVault is hosted at <https://kidsneuro.shinyapps.io/splicevault/>

## Available through Ensembl VEP

SpliceVault is a new VEP plugin released ([Ensembl 111 Release notes](https://www.ensembl.info/2024/01/11/ensembl-111-has-been-released/)) that predicts exon-skipping events and activated cryptic splice sites based on the most common mis-splicing events. This plugin is currently only available on the command-line platform. Please refer to [Use of SpliceVault through Ensembl VEP](https://github.com/kidsneuro-lab/SpliceVault/wiki/Use-of-SpliceVault-through-Ensembl-VEP) for more information.

## Feedback form
The feedback is a google form, located below.
[edit link](https://docs.google.com/forms/d/1QifJ3cmzHgsgw393OMRKq7YjrqJ1wSadkG9M1ED-P04/edit)
[distribution link](https://docs.google.com/forms/d/e/1FAIpQLSeJtgYDy1qf5_Z0wIyz6HmQR0tScgGVjW0QTzhCMwwCHLnA3w/viewform?usp=sf_link)
[preview link](https://docs.google.com/forms/d/e/1FAIpQLSeJtgYDy1qf5_Z0wIyz6HmQR0tScgGVjW0QTzhCMwwCHLnA3w/viewform)

## What was this developed on

-   R 4.1+
-   Hosted on <https://www.shinyapps.io/>
-   Refer to `dependencies.R` for list of packages that are required for SpliceVault to operate properly

## Local installation of SpliceVault

Whilst not geared towards self-hosting, it is possible to install SpliceVault locally on your server/desktop/laptop for development. This requires a few key steps

1.  Postgresql v13 database hosting splicing events. (Note: An [SQL script](https://github.com/kidsneuro-lab/SpliceVault/wiki/SQL-script-to-create-missplicing-database) has been provided on the Wiki for convenience) Note: You may use [dockerised postgres](https://hub.docker.com/_/postgres) or [postgres app](https://postgresapp.com/) (if on a Mac)

2.  Load splicing events datasets into a PostgreSQL instance (see below) using `psql` (**Note:** This will take some time)

3. Ensure dependencies are installed. Please see [`dependencies.R`](https://github.com/kidsneuro-lab/SpliceVault/blob/main/dependencies.R)

3.  Set up .env file

```bash
DB_NAME=<db name>
DB_HOST=<db hostname/ip address>
DB_USER=<db user>
DB_PASSWORD=<db password>
```

5.  Execute `./launch.sh`

## Download Source Data

300K-RNA and 40K-RNA are available at the following links:

<https://storage.googleapis.com/misspl-db-data/misspl_events_300k_hg38.sql.gz> <https://storage.googleapis.com/misspl-db-data/misspl_events_40k_hg19.sql.gz>

The files are stored in google storage and are set to 'requester pays'. Please ensure you have a billing project.
