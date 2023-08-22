FROM rocker/shiny-verse:4.1

# install R packages 
RUN R -e 'install.packages("data.table")'
RUN R -e 'install.packages("DT")'
RUN R -e 'install.packages("rintrojs")'
RUN R -e 'install.packages("shiny")'
RUN R -e 'install.packages("shinyBS")'
RUN R -e 'install.packages("shinycssloaders")'
RUN R -e 'install.packages("shinydashboard")'
RUN R -e 'install.packages("shinyjs")'
RUN R -e 'install.packages("shinyWidgets")'
RUN R -e 'install.packages("tidyverse")'
RUN R -e 'install.packages("DBI")'
RUN R -e 'install.packages("odbc")'
RUN R -e 'install.packages("scales")'
RUN R -e 'install.packages("glue")'
RUN R -e 'install.packages("futile.logger")'
RUN R -e 'install.packages("shinydisconnect")'
RUN R -e 'install.packages("config")'

COPY . /srv/shiny-server/

COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

CMD ["/usr/bin/shiny-server"]