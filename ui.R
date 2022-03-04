

ui <- dashboardPage(
  
  skin = "black",
  title = "SpliceVault",
  
  # HEADER ------------------------------------------------------------------
  
  dashboardHeader(
    
    title = span(img(src = "lariat.svg", height = 35), "SpliceVault"),
    titleWidth = 300,
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
        icon = icon("bars")
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
    collapsed = TRUE,
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
        selectInput(inputId = "tissuesInput", 
                    multiple = F, 
                    choices = c("All", "Brain", "Bile"), 
                    label = "GTEx Tissue"
        ),
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
      includeHTML("google-analytics-dev.html") 
    ),
    
    useShinyjs(),
    introjsUI(),
    
    # MAIN BODY ---------------------------------------------------------------
    
    
    
    column(
      width = 12,
      
      div(
        style = "position: relative;width:100%",
        box(
          width = 'auto',
          height = 'auto',
          fluidRow(
            # menuItem(
            #   "Splice Site",
            #   tabName = "spliceSite",
            #   icon = icon("dna"),
            column(3, 
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
                   )
            ),
            column(3, 
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
                   )
            ),
            column(3, offset = 0, 
                   selectizeInput(
                     inputId = "exonInput",
                     label = "Exon:",
                     choices = NULL,
                     multiple = FALSE
                   ),
                   column(8, radioButtons(
                     inputId = "ssTypeInput",
                     label = "",
                     choices = c('Acceptor', 'Donor'),
                     selected = 'Acceptor',
                     inline = TRUE
                   )),
                   column(4,
                   tags$img(src = "exon.svg", height = "35px", style ="position:absolute; top:7px;")),
                   bsTooltip("ssTypeInput",
                             "The donor at the 3&apos; end of the exon or the acceptor at the 5&apos; end of the exon",
                             placement = "bottom", trigger = "hover")
            ),
            column(3,
                   bsButton(inputId = "confirm", 
                            label = "Generate Table", 
                            icon = icon("play-circle"), 
                            style = "default")
            )
          )
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
            withSpinner(
              div(style = 'overflow-y:scroll;height:55vh;',
                  DT::dataTableOutput("table_ms", height = 'auto') ,
                  type = 4,
                  size = 0.7,
                  color = "#606164"
              )
            )
          ),
          tabPanel(
            title = "FAQ",
            div(style = 'overflow-y:scroll;height:55vh;',
                faq::faq(data = faq, elementId = "faq", faqtitle = "Frequently Asked Questions", height = 'auto')
            )
          )
        )
      )
    )
    
    
  )
)
