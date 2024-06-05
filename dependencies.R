# LIST OF REQUIRED PACKAGES -----------------------------------------------
# Execute with 
# source('dependencies.R')
check_and_install_package <- function(package_name) {
  if (!require(package_name, character.only = TRUE)) {
    install.packages(package_name, dependencies = TRUE)
    library(package_name, character.only = TRUE)
  }
}
check_and_install_package("data.table")
check_and_install_package("DT")
check_and_install_package("rintrojs")
check_and_install_package("shiny")
check_and_install_package("shinyBS")
check_and_install_package("shinycssloaders")
check_and_install_package("shinydashboard")
check_and_install_package("shinyjs")
check_and_install_package("shinyWidgets")
check_and_install_package("tidyverse")
check_and_install_package("DBI")
check_and_install_package("odbc")
check_and_install_package("scales")
check_and_install_package("glue")
check_and_install_package("futile.logger")
check_and_install_package("shinydisconnect")
check_and_install_package("httr")
check_and_install_package("jsonlite")
check_and_install_package("xml2")
