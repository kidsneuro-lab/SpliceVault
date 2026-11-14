source("helpers.R")

server <- function(input, output, session) {
  
  #### Initialise ####
  observeEvent({
    input$dbInput
    input$txTypeInput
  }, {
    flog.debug("Selection of DB & Transcript type")
    flog.debug("Switching to DB %s", isolate(input$dbInput))
    flog.debug("Switching to Transcript type %s", isolate(input$txTypeInput))
    
    # Genes list
    genenames <- get_genes(db = input$dbInput,
                           transcript_type = tolower(input$txTypeInput))$gene_name
    
    geneInput <- isolate(input$geneInput)
    
    if (geneInput %in% genenames & geneInput != "") {
      gene_presel <- geneInput
    } else {
      gene_presel <- genenames[1]
    }
    
    updateSelectizeInput(session = session,
                         inputId = 'geneInput',
                         choices = genenames,
                         selected = gene_presel,
                         server = TRUE)
    
    # Transcripts list
    tx <- get_tx(db = input$dbInput,
                 transcript_type = tolower(isolate(input$txTypeInput)),
                 gene_name = gene_presel)
    
    tx_list <- setNames(tx$id, tx$display_value)
    session$userData$tx <- tx_list
    txInput <- isolate(input$txInput)
    
    if (txInput %in% tx$id & txInput != "") {
      tx_presel <- txInput
    } else {
      tx_presel <- tx_list[1]
    }
    
    updateSelectizeInput(session = session,
                         inputId = 'txInput',
                         choices = tx_list,
                         selected = tx_presel,
                         server = TRUE)
    
    # Exons list
    exons <- get_exons(db = input$dbInput,
                       transcript_id = tx_presel,
                       transcript_type = tolower(isolate(input$txTypeInput)),
                       ss_type = tolower(isolate(input$ssTypeInput)))
    
    exons_list <- setNames(exons$id, exons$display_value)
    session$userData$exons <- exons_list
    exonInput <- isolate(input$exonInput)
    
    if (exonInput %in% exons$id & exonInput != "") {
      ex_presel <- exonInput
    } else {
      ex_presel <- exons_list[1]
    }
    
    updateSelectizeInput(session = session,
                         inputId = 'exonInput',
                         choices = exons_list,
                         selected = ex_presel,
                         server = TRUE)
    
    # Tissues list
    output$tissuesInputUI <- renderUI({
      if (input$dbInput == '300K-RNA (hg38)') {
        tissues <- get_tissues()
        tissues_list <- setNames(c(0, tissues$id), c("All", tissues$display_value))
        session$userData$tissues <- tissues_list
        
        selectizeInput(label = "Tissues (* = Accessible Tissues)", 
                       inputId = 'tissuesInput',
                       choices = tissues_list,
                       selected = tissues_list[1])
        
      } else {
        return(NULL)
      }
    })
  })
  
  #### Handle selection of gene ####
  observeEvent({
    input$geneInput
  }, {
    if (!input$geneInput == "") {
      flog.debug("Selection of Gene")
      
      tx <- get_tx(db = isolate(input$dbInput),
                   transcript_type = tolower(isolate(input$txTypeInput)),
                   gene_name = isolate(input$geneInput))
      
      tx_list <- setNames(tx$id, tx$display_value)
      session$userData$tx <- tx_list
      txInput <- isolate(input$txInput)
      
      if (txInput %in% tx$id & txInput != "") {
        presel <- txInput
      } else {
        presel <- tx_list[1]
      }
      
      updateSelectizeInput(session = session,
                           inputId = 'txInput',
                           choices = tx_list,
                           selected = presel,
                           server = TRUE)
    }
  })
  
  #### Handle selection of Transcript / SS type ####
  observeEvent({
    input$txInput
    input$ssTypeInput
  }, {
    if (!input$txInput == "") {
      flog.debug("Selection of Exon")
      
      exons <- get_exons(db = isolate(input$dbInput),
                         transcript_id = isolate(input$txInput),
                         transcript_type = tolower(isolate(input$txTypeInput)),
                         ss_type = tolower(isolate(input$ssTypeInput)))
      
      exons_list <- setNames(exons$id, exons$display_value)
      session$userData$exons <- exons_list
      exonInput <- isolate(input$exonInput)
      
      if (exonInput %in% exons$id & exonInput != "") {
        presel <- exonInput
      } else {
        presel <- exons_list[1]
      }
      
      updateSelectizeInput(session = session,
                           inputId = 'exonInput',
                           choices = exons_list,
                           selected = presel,
                           server = TRUE)
    }
  })
  
  #### Sidebar settings ####
  
  # grey out # events when 'show all events' is selected
  events <- reactive({
    input$allevents
  })
  observeEvent(events(), {
    shinyjs::toggleState("eventsNoInput", condition = !events())
  })
  
  # grey out exons skipped select box when 'show all cryptics' is selected
  skips <- reactive({
    input$allskips
  })
  observeEvent(skips(), {
    shinyjs::toggleState("esInput", condition = !skips())
  })
  
  # grey out css distance select box when 'show all cryptics' is selected
  cryps <- reactive({
    input$allcryptics
  })
  observeEvent(cryps(), {
    shinyjs::toggleState("cssInput", condition = !cryps())
  })
  
  # hide the underlying selectInput in sidebar for better design
  observeEvent("", {
    hide("tab")
  })
  
  # restore to defaults button
  observeEvent(input$restore, {
    updateSliderInput(session, "eventsNoInput", value = 4)
    updateSliderInput(session, "esInput", value = 2)
    updateSliderInput(session, "cssInput", value = 600)
    updateCheckboxInput(session = session,
                        inputId = "allevents",
                        value = FALSE)
    updateCheckboxInput(session = session,
                        inputId = "allskips",
                        value = FALSE)
    updateCheckboxInput(session = session,
                        inputId = "allcryptics",
                        value = FALSE)
    updateSelectizeInput(session = session,
                         inputId = 'dbInput',
                         selected = '300K-RNA (hg38)')
    updateSelectizeInput(session = session,
                         inputId = 'tissuesInput',
                         selected = 0)
  })
  
  output$title_panel <- renderText({
    "Mis-Splicing Events Table"
  })

  
  #### Generate table ####
  # What one Generate Table click asks for, resolved in this user's session.
  # In Variant mode the variant is looked up with Ensembl and converted to
  # database IDs; a failed lookup carries only its error message, and the
  # table and legend below stop there.
  request <- eventReactive(input$confirm, {
    if (input$mode == "Variant"){
      variant_input_data <- get_variant_data_restapi("Variant", input$variant, input$ssTypeInput)
      if (variant_input_data[[2]][1] == "error") {
        return(list(error = variant_input_data[[1]][1]))
      }
      variant_code_data <- get_variant_sql_codes(
        tolower(variant_input_data[[4]][1]),
        variant_input_data[[3]][1],
        variant_input_data[[2]][1]
      )
      mod_geneInput <- variant_input_data[[1]][1]
      mod_txName <- variant_input_data[[2]][1]
      mod_exonName <- variant_input_data[[3]][1]
      mod_ssTypeInput <- variant_input_data[[4]][1]
      mod_txInput <- variant_code_data$transcript_id[1]
      mod_exonInput <- variant_code_data$exon_id[1]
    } else if (input$mode == "Gene/Transcript/Exon"){
      mod_geneInput <- input$geneInput
      mod_txName <- names(session$userData$tx)[session$userData$tx==input$txInput]
      mod_exonName <- names(session$userData$exons)[session$userData$exons==input$exonInput]
      mod_ssTypeInput <- input$ssTypeInput
      mod_txInput <- input$txInput
      mod_exonInput <- input$exonInput
    }
    
    tissue <- if (input$tissuesInput == 0) NULL else
      names(session$userData$tissues)[session$userData$tissues == input$tissuesInput]
    title <- events_table_title(db = input$dbInput,
                                transcript = mod_txName,
                                gene = mod_geneInput,
                                ss_type = mod_ssTypeInput,
                                exon = mod_exonName,
                                events_no = if (input$allevents == FALSE) input$eventsNoInput else NULL,
                                max_skipped = if (input$allskips == FALSE) input$esInput else NULL,
                                max_cryptic = if (input$allcryptics == FALSE) input$cssInput else NULL,
                                tissue = tissue)

    list(title = title,
         legend = input$dbInput == '300K-RNA (hg38)' & input$tissuesInput == 0,
         transcript_id = mod_txInput,
         exon_id = mod_exonInput,
         ss_type = tolower(mod_ssTypeInput))
  })
  
  output$table_title <- renderText({
    if (!is.null(request()$error)) request()$error else request()$title
  })
  
  output$clinAccessTissues <- renderUI({
    req(is.null(request()$error), request()$legend)
    tags$span("B - Blood Whole; F - Cells - Cultured fibroblasts; L - Cells - EBV-transformed lymphocytes; M - Muscle - Skeletal")
  })
  
  #### Output table formatter ####
  table_ms <- eventReactive(request(), {
    req(is.null(request()$error))
    
    columns <- events_table_columns(input$dbInput, tissue_selected = input$tissuesInput != 0)
    # NULL leaves a filter off ("Show all").
    max_cryptic <- if (input$allcryptics == FALSE) input$cssInput else NULL
    max_skipped <- if (input$allskips == FALSE) input$esInput else NULL
    limit <- if (input$allevents == FALSE) input$eventsNoInput + 1 else NULL

    set_table <- get_misspl_stats(db = input$dbInput,
                                  ss_type = request()$ss_type,
                                  exon_id = request()$exon_id,
                                  transcript_id = request()$transcript_id,
                                  max_cryptic = max_cryptic,
                                  max_skipped = max_skipped,
                                  limit = limit,
                                  tissue_id = input$tissuesInput,
                                  events_limit = input$eventsNoInput + 1)
    
    set_table <- format_events(set_table, columns$genome)
    title_panel <- request()$title

    datatable(
      set_table,
      rownames = FALSE,
      escape = FALSE,
      extensions = "Buttons",
      colnames = columns$colnames,
      class = 'cell-border stripe',
      options = list(
        columnDefs = columns$columnDefs,
        dom = 'Bfrtp',
        buttons = list('copy', list(
          extend = 'collection',
          buttons =list(
            list(
              extend = "excel",
              messageTop = title_panel
            ),
            list(
              extend = "csv",
              messageTop = title_panel
            ),
            list(
              extend = "pdf",
              messageTop = title_panel,
              orientation = 'landscape'
            )
          ),
          text = 'Download')),
        pageLength = if(input$allevents == FALSE){input$eventsNoInput + 1}else{11},
        #lengthMenu = c(seq(5, 10, 20)),
        ordering = FALSE,
        #scrollY="350px",
        scrollX=FALSE,
        autoWidth = FALSE
      )
    ) %>%
      formatStyle( 0, target= 'row',lineHeight='100%')
    
  })
  
  
  output$table_ms <- DT::renderDataTable({
    table_ms() 
  }, server = FALSE)
  
  # disable confirm button until inputs are available
  observe({
    if(is.null(input$exonInput) || input$exonInput == "" || 
       is.null(input$geneInput) || input$geneInput == "" ||
       is.null(input$txInput) || input$txInput == ""){
      disable("confirm")
    }
    else{
      enable("confirm")
    }
  })
}