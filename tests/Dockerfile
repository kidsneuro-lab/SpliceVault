# Test runner image: R, the app's renv packages and testthat. The repository
# itself is bind-mounted at run time (see tests/docker-compose.yml), so this
# only needs rebuilding when renv.lock or this file changes.
FROM rocker/r-ver:4.4.3

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libcurl4-openssl-dev libssl-dev libxml2-dev libpq-dev unixodbc-dev \
      libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
      libpng-dev libtiff-dev libjpeg-dev \
 && rm -rf /var/lib/apt/lists/*

# Keep the package library outside the project, so the bind-mounted repo's
# renv/library (host builds, gitignored) is never used. Packages come as
# prebuilt binaries from Posit Package Manager's repository for this image's
# Ubuntu release (noble); renv still installs the versions in renv.lock.
ENV RENV_PATHS_LIBRARY=/opt/renv/library \
    RENV_PATHS_CACHE=/opt/renv/cache \
    RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/__linux__/noble/latest

WORKDIR /opt/renv/project
COPY renv.lock .Rprofile ./
COPY renv/activate.R renv/

# testthat and httptest (replays recorded Ensembl REST responses) are
# test-only, so they are installed here and kept out of renv.lock.
RUN Rscript -e ' \
  stopifnot(as.character(getRversion()) == renv::lockfile_read("renv.lock")$R$Version); \
  renv::restore(prompt = FALSE); \
  renv::install(c("testthat@3.3.2", "httptest@4.2.4"), prompt = FALSE)'

WORKDIR /app
