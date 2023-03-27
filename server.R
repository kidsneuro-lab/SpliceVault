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
  
  # observeEvent(input$variant, {
  #   
  #   if (input$mode == "Variant"){
  #     variant_input_data <<- get_variant_data_restapi("Variant", input$variant)
  #     variant_code_data <<- get_variant_sql_codes(
  #       tolower(variant_input_data[[4]][1]),
  #       variant_input_data[[3]][1],
  #       variant_input_data[[2]][1]
  #     )
  #     mod_geneInput <- variant_input_data[[1]][1]
  #     mod_txInput <- variant_input_data[[2]][1]
  #     mod_exonInput <- variant_input_data[[3]][1]
  #     mod_ssTypeInput <- variant_input_data[[4]][1]
  #   }
  # })
  
  
  #### Generate table ####
  observeEvent(input$confirm, {
    
    if (input$mode == "Variant"){

          variant_input_data <<- get_variant_data_restapi("Variant", input$variant, input$ssTypeInput)
          variant_code_data <<- get_variant_sql_codes(
            tolower(variant_input_data[[4]][1]),
            variant_input_data[[3]][1],
            variant_input_data[[2]][1]
          )
      mod_geneInput <- variant_input_data[[1]][1]
      mod_txInput <- variant_input_data[[2]][1]
      mod_exonInput <- variant_input_data[[3]][1]
      mod_ssTypeInput <- variant_input_data[[4]][1]
    }
    
    if (input$dbInput == '300K-RNA (hg38)' & input$tissuesInput == 0) {
      output$clinAccessTissues <- renderUI({
        tags$span("B - Blood Whole; F - Cells - Cultured fibroblasts; L - Cells - EBV-transformed lymphocytes; M - Muscle - Skeletal")
      })
    } else {
      output$clinAccessTissues <- NULL
    }
    
    if (isolate(input$allcryptics) == TRUE & isolate(input$allskips) == TRUE) {
      settings = ''
    } else if (isolate(input$allcryptics) == TRUE & isolate(input$allskips) == FALSE) {
      settings = paste0(" (max ", isolate(input$esInput), " exons skipped)")
    } else if (isolate(input$allskips) == TRUE & isolate(input$allcryptics) == FALSE) {
      settings = paste0(" (cryptics within +/-", isolate(input$cssInput), ")")
    } else {
      settings = paste0(" (max ", isolate(input$esInput), " exons skipped, cryptics within +/-", isolate(input$cssInput), " nt)")
    }
    if (isolate(input$allevents) == TRUE) {
      events = "all"
    } else {
      events  = paste("top ", isolate(input$eventsNoInput))
    }
    if (input$mode == "Gene/Transcript/Exon"){
      output$table_title <- renderText(paste0("Showing ", events, 
                                              " unannotated events in ", isolate(input$dbInput),
                                              " for ", gsub(' \\(Canonical\\)', '', names(session$userData$tx)[session$userData$tx==isolate(input$txInput)]), " ",
                                              ifelse(isolate(input$tissuesInput) == 0, "", paste0(" [", names(session$userData$tissues)[session$userData$tissues==isolate(input$tissuesInput)], "] ")),
                                              "(",isolate(input$geneInput), ")",
                                              " ", isolate(input$ssTypeInput)," " , names(session$userData$exons)[session$userData$exons==isolate(input$exonInput)],
                                              settings ))
    } else if (input$mode == "Variant"  & mod_txInput != "error"){
      output$table_title <- renderText(paste0("Showing ", events, 
                                              " unannotated events in ", isolate(input$dbInput),
                                              " for ", gsub(' \\(Canonical\\)', '', mod_txInput), " ",
                                              ifelse(isolate(input$tissuesInput) == 0, "", paste0(" [", names(session$userData$tissues)[session$userData$tissues==isolate(input$tissuesInput)], "] ")),
                                              "(",mod_geneInput, ")",
                                              " ", mod_ssTypeInput," " , mod_exonInput,
                                              settings ))
      
    } else if (input$mode == "Variant" & mod_txInput == "error"){
      output$table_title <- renderText(mod_geneInput)
    }
    
  })
  
  #### Output table formatter ####
  table_ms <- eventReactive(input$confirm, {
    
    if (input$mode == "Variant"){
      mod_txInput <- variant_code_data$transcript_id[1]
      mod_exonInput <- variant_code_data$exon_id[1]
      mod_ssTypeInput <- tolower(variant_input_data[[4]][1])
      
      
    }else if (input$mode == "Gene/Transcript/Exon"){
      mod_txInput <- input$txInput
      mod_exonInput <- input$exonInput
      mod_ssTypeInput <- tolower(input$ssTypeInput)
    }
    
    if (input$dbInput == '300K-RNA (hg38)') {
      db = '300k_hg38'
      if (input$tissuesInput == 0) {
        set_colnames = c('Event', 'Same Frame?', 'GTEx?', 'SRA?', 'Skipped Exons', 'Cryptic Position', 
                         'Samples (GTEx)', 'Samples (SRA)', 'Max Reads (GTEx)', 'Total Samples', 'Accessible Tissues (GTEx)', 'Splice Junction', 'IGV')
        columnDefs <- list(list(className = 'dt-center', targets = c(0:5,10:12)),
                           list(className = 'dt-right', targets = c(6:9)),
                           list(
                             targets = c(1,2,3),
                             render = JS(
                               "function(data, type, row, meta) {",
                               "return data == 'Yes' ? '<span>&#10003;</span>' : '';",
                               "}")
                           ),
                           list(
                             targets = 10,
                             render = JS(
                               "function(data, type, row, meta) {",
                               "return data.trim().charAt(data.trim().length-1) == ',' ? data.trim().substr(0, data.trim().length - 1) : data;",
                               "}")
                           ))
        
        
      } else {
        set_colnames = c('Event', 'Same Frame?', 'GTEx?', 'Skipped Exons', 'Cryptic Position', 
                         'Samples (GTEx)', 'Max Reads (GTEx)', 'Splice Junction', 'IGV')
        columnDefs <- list(list(className = 'dt-center', targets = c(0:4,6:8)),
                           list(className = 'dt-right', targets = c(5)),
                           list(
                             targets = c(1,2),
                             render = JS(
                               "function(data, type, row, meta) {",
                               "return data == 'Yes' ? '<span>&#10003;</span>' : '';",
                               "}")
                           ))
      }
      genome = 'hg38'
    } else if (input$dbInput == '40K-RNA (hg19)') {
      db = '40k_hg19'
      set_colnames = c('Event', 'Same Frame?', 'GTEx?', 'Intropolis?', 'Skipped Exons', 'Cryptic Position', 
                       'Samples (GTEx)', 'Samples (Intropolis)', 'Max Reads (GTEx)', 'Total Samples', 'Splice Junction', 'IGV')
      columnDefs <- list(list(className = 'dt-center', targets = c(0:5,10:11)),
                         list(className = 'dt-right', targets = c(9)),
                         list(
                           targets = c(1,2,3),
                           render = JS(
                             "function(data, type, row, meta) {",
                             "return data == 'Yes' ? '<span>&#10003;</span>' : '';",
                             "}")
                         ))
      genome = 'hg19'
    }
    if (input$allcryptics == FALSE) {
      cryp_filt = paste0(" AND (ABS(cryptic_distance) <= ", gsub('\\+/-| nt', '', input$cssInput), " OR cryptic_distance IS NULL)")
    } else {
      cryp_filt = ""
    }
    if (input$allskips == FALSE) {
      es_filt = paste0(" AND (skipped_exons_count <= ", input$esInput, " OR skipped_exons_count IS NULL)")
    } else {
      es_filt = ""
    }
    if (input$allevents == FALSE) {
      event_filt = paste0(" LIMIT ", input$eventsNoInput + 1)
    } else {
      event_filt = ""
    }
    
    set_table <- get_misspl_stats(db = input$dbInput, 
                                  ss_type = mod_ssTypeInput, 
                                  exon_id = mod_exonInput, 
                                  transcript_id = mod_txInput, 
                                  cryp_filt = cryp_filt, 
                                  es_filt = es_filt, 
                                  event_filt = event_filt, 
                                  tissue_id = input$tissuesInput,
                                  events_limit = input$eventsNoInput + 1)
    
    ann_samples <- set_table %>% filter(splicing_event_class == 'normal splicing') %>% pull(sample_count)
    
    if (input$dbInput == '300K-RNA (hg38)') {
      set_table <- set_table %>% 
        rowwise() %>%
        mutate(start = min(donor_pos, acceptor_pos),
               end = max(donor_pos, acceptor_pos)) %>% ungroup() %>% 
        mutate(sj = paste0(paste(chr, paste(start, end, sep = '-'), sep = ':')),
               samples_prop = scales::percent(sample_count / ann_samples, accuracy = 0.1)) %>%
        rowwise() %>%
        mutate(splicing_event_class = gsub('normal', 'annotated', splicing_event_class),
               igv = gsub("amp;","",tags$a(href=paste0("http://localhost:60151/goto?locus=", sj, "&genome=", genome), "link")),
               #rank = row_number(),
               cryptic_distance = ifelse(cryptic_distance > 0, 
                                         paste0('+', as.character(cryptic_distance)), 
                                         as.character(cryptic_distance)),
               sample_count = paste0(sample_count, ' (', samples_prop, ')')) %>%
        select(-chr, -donor_pos, -acceptor_pos, -start, -end, -samples_prop)
    } else {
      set_table <- set_table %>% 
        rowwise() %>%
        mutate(start = min(donor_pos, acceptor_pos),
               end = max(donor_pos, acceptor_pos)) %>% ungroup() %>% 
        mutate(sj = paste0(paste(chr, paste(start, end, sep = '-'), sep = ':')),
               samples_prop = scales::percent(sample_count / ann_samples, accuracy = 0.1)) %>%
        rowwise() %>%
        mutate(splicing_event_class = gsub('normal', 'annotated', splicing_event_class),
               igv = gsub("amp;","",tags$a(href=paste0("http://localhost:60151/goto?locus=", sj, "&genome=", genome), "link")),
               #rank = row_number(),
               cryptic_distance = ifelse(cryptic_distance > 0, 
                                         paste0('+', as.character(cryptic_distance)), 
                                         as.character(cryptic_distance)),
               sample_count = paste0(sample_count, ' (', samples_prop, ')')) %>%
        select(-chr, -donor_pos, -acceptor_pos, -start, -end, -samples_prop)
    }
    
    # http://localhost:port/goto?locus=2:79087958-79087659&genome=hg38
    if (isolate(input$allcryptics) == TRUE & isolate(input$allskips) == TRUE) {
      settings = ''
    } else if (isolate(input$allcryptics) == TRUE & isolate(input$allskips) == FALSE) {
      settings = paste0(" (max ", isolate(input$esInput), " exons skipped)")
    } else if (isolate(input$allskips) == TRUE & isolate(input$allcryptics) == FALSE) {
      settings = paste0(" (cryptics within +/-", isolate(input$cssInput), ")")
    } else {
      settings = paste0(" (max ", isolate(input$esInput), " exons skipped, cryptics within +/-", isolate(input$cssInput), " nt)")
    }
    if (isolate(input$allevents) == TRUE) {
      events = "all"
    } else {
      events  = paste("top ", isolate(input$eventsNoInput))
    }
    title_panel <- paste0("Showing ", events, 
                          " unannotated events in ", isolate(input$dbInput),
                          " for ", gsub(' \\(Canonical\\)', '', isolate(input$txInput)),
                          "(",isolate(input$geneInput), ")",
                          " ", isolate(input$ssTypeInput)," " ,isolate(input$exonInput),
                          settings )
    datatable(
      set_table,
      rownames = FALSE,
      escape = FALSE,
      extensions = "Buttons",
      colnames = set_colnames,
      class = 'cell-border stripe',
      options = list(
        columnDefs = columnDefs,
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
        pageLength = 5,
        #lengthMenu = c(seq(5, 150, 10)),
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