

ui <- dashboardPage(
  
  skin = "black",
  title = "SpliceVault-40K",
  
  # HEADER ------------------------------------------------------------------
  
  dashboardHeader(
    
    title = span(img(src = "lariat.svg", height = 35), "SpliceVault-40K"),
    titleWidth = 400,
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
        sliderInput("eventsNoInput", "Number of Events:",
                    min = 1, max = 10,
                    value = 4, step = 1),
        checkboxInput("allevents", "Show all Events", value = FALSE),
        sliderInput("cssInput", "Show Cryptics Within:",
                    min = 50, max = 1000,
                    value = 250, step = 50,
                    pre = "+/-", post= ' nt'),
        checkboxInput("allcryptics", "Show all Cryptics", value = FALSE),
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
                     label = "Donor:",
                     choices = NULL,
                     multiple = FALSE
                   )
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
