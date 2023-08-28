

ui <- dashboardPage(
  
  skin = "black",
  title = "SpliceVault",
  
  # HEADER ------------------------------------------------------------------
  
  dashboardHeader(
    
    title = span(img(src = "lariat.svg", height = 35), "SpliceVault"),
    titleWidth = 300,
    
    tags$li(class = "dropdown", actionButton(onclick="window.open('https://github.com/kidsneuro-lab/SpliceVault/issues', '_blank')",
                                             icon = icon("bug"),
                                             inputId = 'reportIssue',
                                             label = "Report an issue",
                                             btn_type = "button", width = 200,
                                             style = "padding-bottom:0px; padding-top:0px; font-size: 16px; height: 50px;")),
    
    dropdownMenu(
      type = "notifications", 
      headerText = strong("Help"), 
      icon = icon("question"), 
      badgeStatus = NULL,
      notificationItem(
        text = steps$text[1],
        icon = icon("dna")
      ),
      notificationItem(
        text = steps$text[2],
        icon = icon("cog")
      ),
      notificationItem(
        text = steps$text[3],
        icon = icon("question")
      )
    )
  ),
  # SIDEBAR -----------------------------------------------------------------
  
  dashboardSidebar(
    width = 300,
    collapsed = FALSE,
    sidebarMenu(h4("Customise Settings", align = "center"),
      # menuItem(
      #   "Settings",
      #   tabName = "settings",
      #   icon = icon("sliders-h"),
        sliderInput("eventsNoInput", "Number of Events:",
                    min = 1, max = 10,
                    value = 4, step = 1),
        checkboxInput("allevents", "Show all Events", value = FALSE),
        sliderInput("esInput", "Maximum Number of Exons Skipped:",
                    min = 1, max = 10,
                    value = 2, step = 1),
        checkboxInput("allskips", "Show all Exon Skipping", value = FALSE),
        sliderInput("cssInput", "Show Cryptics Within:",
                    min = 50, max = 1000,
                    value = 600, step = 100,
                    pre = "+/-", post= ' nt'),
        checkboxInput("allcryptics", "Show all Cryptics", value = FALSE),
        uiOutput(outputId = "tissuesInputUI"),
        br(),
        fluidRow(
          column(6, align="center", offset = 3,
                 bsButton(inputId = "restore", 
                          label = "Restore Settings", 
                          style = "basic")
          )
        ),
        br(),
        br()
      ),
      br(),
      br()
      
    #)
  ),
  
  
  # BODY --------------------------------------------------------------------
  
  dashboardBody(
    tags$head(
      tags$link(
        rel = "stylesheet", 
        type = "text/css", 
        href = "krna_style.css"),
      tags$link(rel = "shortcut icon", href = "favicon.svg"),      
      includeHTML("google-analytics.html") 
    ),
    
    useShinyjs(),
    introjsUI(),
    
    # MAIN BODY ---------------------------------------------------------------
    
    fluidRow(
      column(
        width = 9,
      wellPanel(style = "background-color: #ffffff;",
        tabsetPanel(
                id = "mode",
                tabPanel("Variant",
                         br(),
                         div(style="display: inline-block; vertical-align:top; width: 100%;",
                             textInput(
                               inputId = "variant",
                               label = "Variant:",
                               value = ""
                             ),
                         ),
                         br()
                ),
                tabPanel("Gene/Transcript/Exon",
                         br(),
                         div(style="display: inline-block; vertical-align:top; width: 33%;",
                                      selectizeInput(
                                        inputId = "geneInput",
                                        label = "Gene Name:",
                                        choices = NULL,
                                        multiple = FALSE
                                      ),
                                      radioButtons(
                                        inputId = "dbInput",
                                        label = "",
                                        choices = c('300K-RNA (hg38)','40K-RNA (hg19)'),
                                        selected = '300K-RNA (hg38)',
                                        inline = TRUE
                                      ),
                           ),
                           div(style="display: inline-block; vertical-align:top; width: 33%;",
                               selectizeInput(
                                 inputId = "txInput",
                                 label = "Transcript:",
                                 choices = NULL,
                                 multiple = FALSE
                               ),
                               radioButtons(
                                 inputId = "txTypeInput",
                                 label = "",
                                 choices = c('RefSeq', 'Ensembl'),
                                 selected = 'RefSeq',
                                 inline = TRUE
                               ),
                           ),
                           div(style="display: inline-block; vertical-align:top; width: 33%;",
                               selectizeInput(
                                 inputId = "exonInput",
                                 label = "Exon:",
                                 choices = NULL,
                                 multiple = FALSE
                               ),
                               fluidRow(
                               column(6,
                               radioButtons(
                                 inputId = "ssTypeInput",
                                 label = "",
                                 choices = c('Acceptor', 'Donor'),
                                 selected = 'Acceptor',
                                 inline = TRUE
                               ),
                               bsTooltip("ssTypeInput",
                                         "The donor at the 3&apos; end of the exon or the acceptor at the 5&apos; end of the exon",
                                         placement = "bottom", trigger = "hover")
                               ),
                               column(6,
                                      tags$img(src = "exon.svg", height = "35px")
                               )),
                           ),
                         br()
                )),
      )),
      
      column(
        width = 3,
        br(), 
        bsButton(inputId = "confirm",
                  label = "Generate Table",
                  icon = icon("play-circle")),
        br(),
        br()
      )
),
      div(
        style = "position: relative;width:100%",
        tabBox(
          id = "output_table",
          width = 'auto',
          height = 'auto',
          tabPanel(
            title = uiOutput("title_panel"),
            div(h4(uiOutput("table_title"))),
            br(),
            div(style = 'overflow-y:scroll;height:55vh;',
                withSpinner(
                  DT::dataTableOutput("table_ms", height = 'auto') ,
                  type = 1,
                  size = 2,
                  color = "#5977BA"
              ),
              htmlOutput(outputId = "clinAccessTissues")
            ),
          ),
          tabPanel(
            title = "FAQ",
            div(
              includeHTML("faq.html")
            )
          )
        )
      )
    )
)
