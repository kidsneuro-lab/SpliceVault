source("helpers.R")

server <- function(input, output, session) {
  
  #### Dropdowns ####
  # One observer per level, each running one (cached) query: dataset or
  # transcript type -> genes, gene -> transcripts, transcript or splice site
  # type -> exons. A level passes its selection down through a reactiveVal that
  # also records the dataset and transcript type it belongs to. Setting a
  # reactiveVal to the value it already holds does not invalidate it, so when
  # the browser echoes back a selection the server just made, the level below
  # does not run again. freezeReactiveValue() cannot do this: when a level
  # keeps the same selection the browser sends nothing back, so a frozen input
  # would never thaw into a refresh for the new dataset.
  selected_gene <- reactiveVal()
  selected_tx <- reactiveVal()

  # Keeps the current selection when it is still an option, otherwise the
  # first option.
  keep_or_first <- function(current, options) {
    if (!is.null(current) && current != "" && current %in% options) current else options[1]
  }

  observeEvent({
    input$dbInput
    input$txTypeInput
  }, {
    flog.debug("Switching to DB %s, transcript type %s", input$dbInput, input$txTypeInput)
    transcript_type <- tolower(input$txTypeInput)
    genenames <- get_genes(db = input$dbInput, transcript_type = transcript_type)$gene_name
    gene <- keep_or_first(isolate(input$geneInput), genenames)
    updateSelectizeInput(session = session, inputId = 'geneInput',
                         choices = genenames, selected = gene, server = TRUE)
    selected_gene(list(db = input$dbInput, transcript_type = transcript_type, gene = gene))
  })

  observeEvent(input$geneInput, {
    if (input$geneInput != "") {
      selected_gene(list(db = isolate(input$dbInput),
                         transcript_type = tolower(isolate(input$txTypeInput)),
                         gene = input$geneInput))
    }
  })

  observeEvent(selected_gene(), {
    flog.debug("Selection of Gene")
    sel <- selected_gene()
    tx <- get_tx(db = sel$db, transcript_type = sel$transcript_type, gene_name = sel$gene)
    tx_list <- setNames(tx$id, tx$display_value)
    session$userData$tx <- tx_list
    tx_id <- keep_or_first(isolate(input$txInput), tx_list)
    updateSelectizeInput(session = session, inputId = 'txInput',
                         choices = tx_list, selected = tx_id, server = TRUE)
    selected_tx(list(db = sel$db, transcript_type = sel$transcript_type, tx = as.character(tx_id)))
  })

  observeEvent(input$txInput, {
    if (input$txInput != "") {
      selected_tx(list(db = isolate(input$dbInput),
                       transcript_type = tolower(isolate(input$txTypeInput)),
                       tx = as.character(input$txInput)))
    }
  })

  # A new transcript (from a dataset, transcript type, gene or transcript
  # change) selects the first exon, so the user re-evaluates which exon to
  # interrogate (#61). Switching Acceptor/Donor keeps the exon when it has that
  # splice site.
  update_exons <- function(sel, keep_exon) {
    flog.debug("Selection of Exon")
    exons <- get_exons(db = sel$db, transcript_id = sel$tx,
                       transcript_type = sel$transcript_type,
                       ss_type = tolower(isolate(input$ssTypeInput)))
    exons_list <- setNames(exons$id, exons$display_value)
    session$userData$exons <- exons_list
    selected <- if (keep_exon) keep_or_first(isolate(input$exonInput), exons_list) else exons_list[1]
    updateSelectizeInput(session = session, inputId = 'exonInput',
                         choices = exons_list, selected = selected, server = TRUE)
  }

  observeEvent(selected_tx(), {
    update_exons(selected_tx(), keep_exon = FALSE)
  })

  observeEvent(input$ssTypeInput, {
    sel <- isolate(selected_tx())
    if (is.null(sel)) return()  # the splice site type arrives before any transcript
    update_exons(sel, keep_exon = TRUE)
  }, ignoreInit = TRUE)

  # Tissue dropdown, for 300K-RNA only. It depends on the dataset alone, so
  # switching transcript type keeps the selected tissue.
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

  # The selected tissue, 0 for all tissues. 40K-RNA has no tissues, but the
  # browser keeps the last value of a dropdown it no longer shows, so a tissue
  # picked on 300K-RNA would otherwise still apply after switching to 40K-RNA.
  tissue_id <- reactive({
    if (input$dbInput == '300K-RNA (hg38)' && !is.null(input$tissuesInput)) input$tissuesInput else 0
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
  
  # Restore Settings: the sidebar settings and the tissue go back to their
  # defaults. The dataset, transcript type, splice site and the gene,
  # transcript and exon are main-form selections and stay as they are (#63).
  # On 40K-RNA there is no tissue dropdown, so the tissue update does nothing.
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
    
    tissue <- if (tissue_id() == 0) NULL else
      names(session$userData$tissues)[session$userData$tissues == tissue_id()]
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
         legend = input$dbInput == '300K-RNA (hg38)' & tissue_id() == 0,
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
    
    columns <- events_table_columns(input$dbInput, tissue_selected = tissue_id() != 0)
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
                                  tissue_id = tissue_id(),
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