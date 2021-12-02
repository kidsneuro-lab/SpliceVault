
server <- function(input, output, session) {

  # change gene name options based on selected database and transcript type. default to prior selected gene name if available
  observeEvent({
    input$dbInput
    input$txTypeInput
  }, {
    if (input$dbInput == '300K-RNA (hg38)' & input$txTypeInput == 'Ensembl') {
      genenames <- gene_names_300k_ensembl
    } else if (input$dbInput == '300K-RNA (hg38)' & input$txTypeInput == 'RefSeq') {
      genenames <- gene_names_300k_refseq
    } else if (input$dbInput == '40K-RNA (hg19)' & input$txTypeInput == 'Ensembl') {
      genenames <- gene_names_40k_ensembl
    } else if (input$dbInput == '40K-RNA (hg19)' & input$txTypeInput == 'RefSeq') {
      genenames <- gene_names_40k_refseq
    }
    if (input$geneInput %in% genenames) {
      presel = input$geneInput 
    } else {
      presel = genenames[1]
    }
    # update UI
    updateSelectizeInput(session = session,
                         inputId = 'geneInput',
                         choices = genenames,
                         selected = presel,
                         server = TRUE)
  })

  db_dict <- data.frame(input = c('300K-RNA (hg38)','40K-RNA (hg19)'),
                        db = '300k_hg38', '40k_hg19')
  
  #get list of transcripts for select box based on selected gene
  observeEvent({input$geneInput
                input$txTypeInput
                },{
    tx_query <- paste0("SELECT tx_id || CASE WHEN canonical = 1 THEN ' (Canonical)' ELSE '' END AS display_value,
                                     gene_tx_id
                                     FROM misspl_app.misspl_events_", db_dict$db[which(db_dict$input == isolate(input$dbInput))],"_tx
                                     WHERE gene_name = '",isolate(input$geneInput), "' 
                                     AND transcript_type = '",  tolower(isolate(input$txTypeInput)), "'
                                     ORDER BY canonical DESC, tx_id;")
    txs <- dbGetQuery(con, tx_query)
    if (input$txInput  != "" & input$txInput %in% txs$display_value) {
      presel = input$txInput
    } else {
      presel = txs$display_value[1]
    }
    
    
    updateSelectizeInput(session = session,
                         inputId = 'txInput',
                         choices = txs$display_value,
                         selected = presel,
                         server = TRUE)
                })
  
  # get list of exon numbers for selected transcript
  observeEvent({input$dbInput
                input$txTypeInput
                input$txInput
                input$ssTypeInput},{
    ex_query <- paste0("SELECT DISTINCT evnt.exon_no || ' (g.' || splice_site_pos || ')' AS display_value, exon_no AS exon_no
    FROM misspl_app.misspl_events_", db_dict$db[which(db_dict$input == isolate(input$dbInput))], "_tx tx
    JOIN misspl_app.misspl_events_", db_dict$db[which(db_dict$input == isolate(input$dbInput))], "_events evnt
    ON tx.gene_tx_id = evnt.gene_tx_id
    AND ss_type = '", tolower(isolate(input$ssTypeInput)), "'
    AND tx.transcript_type = '", tolower(isolate(input$txTypeInput)), "'
    AND tx.tx_id = '", gsub(' \\(Canonical\\)', '', isolate(input$txInput)), "' ORDER BY exon_no ASC;")
    ex <- dbGetQuery(con, ex_query)
    
    if (as.numeric(gsub(' \\((.*?)\\)', '', input$exonInput)) %in% ex$exon_no) {
      presel = ex$display_value[which(ex$exon_no == gsub(' \\((.*?)\\)', '', input$exonInput))]
    } else {
      presel = ex$display_value[1]
    }
    
    updateSelectizeInput(session = session,
                         inputId = 'exonInput',
                         choices = ex$display_value,
                         selected = presel,
                         server = TRUE)
  })
  
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
    updateSliderInput(session, "eventsNoInput", value=4)
    updateSliderInput(session, "esInput", value=2)
    updateSliderInput(session, "cssInput", value=600)
    updateCheckboxInput(session=session, inputId="allevents", value = FALSE)
    updateCheckboxInput(session=session, inputId="allskips", value = FALSE)
    updateCheckboxInput(session=session, inputId="allcryptics", value = FALSE)
  })
  
  # UI - OUTCOME - 3 ---------------------------------------------------



  # output$output_table <- renderUI({
  #   div(
  #     style = "position: relative;width:100%",
  #     tabBox(
  #       id = "output_table",
  #       width = 'auto',
  #       height = 'auto',
  #       tabPanel(
  #         title = uiOutput("title_panel"),
  #         withSpinner(
  #           DT::dataTableOutput("table_ms", height = 'auto'),
  #           type = 4,
  #           size = 0.7,
  #           color = "#606164"
  #         )
  #       )
  #     )
  #   )
  # })
  
  
  output$title_panel <- renderText({
    "Mis-Splicing Events Table"
  })
  
  observeEvent(input$confirm, {
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
    output$table_title <- renderText(paste0("Showing ", events, 
                                            " unannotated events in ", isolate(input$dbInput),
                                            " for ", gsub(' \\(Canonical\\)', '', isolate(input$txInput)),
                                            "(",isolate(input$geneInput), ")",
                                            " ", isolate(input$ssTypeInput)," " ,isolate(input$exonInput),
                                            settings ))
    
  })
  # output$title_panel <- eventReactive(input$confirm, {
  #   paste0("Showing Top ", input$eventsNoInput, " events in ", input$dbInput)
  # }, ignoreNULL = FALSE)
  
  table_ms <- eventReactive(input$confirm, {
    if (input$dbInput == '300K-RNA (hg38)') {
      db = '300k_hg38'
      second = 'sra'
      third = 'max_uniq_reads'
      set_colnames = c('Event', 'Same Frame?', 'GTEx?', 'SRA?', 'Skipped Exons', 'Cryptic Distance', 
                       'Samples (GTEx)', 'Samples (SRA)', 'Max Reads (GTEx)', 'Total Samples', 'Splice Junction', 'IGV')
      genome = 'hg38'
    } else if (input$dbInput == '40K-RNA (hg19)') {
      db = '40k_hg19'
      second = 'intropolis'
      third = 'gtex_max_uniq_map_reads'
      set_colnames = c('Event', 'Same Frame?', 'GTEx?', 'Intropolis?', 'Skipped Exons', 'Cryptic Distance', 
                       'Samples (GTEx)', 'Samples (Intropolis)', 'Max Reads (GTEx)', 'Total Samples', 'Splice Junction', 'IGV')
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
    table_query <- paste0("SELECT evnt.splicing_event_class,
                                  evnt.missplicing_inframe,
                                  evnt.in_gtex,
                                  evnt.in_", second,",
                                  evnt.skipped_exons_id,
                                  evnt.cryptic_distance,
                                  evnt.gtex_sample_count,
                                  evnt.",second,"_sample_count,
                                  evnt.",third,",
                                  evnt.sample_count,
                                  evnt.chr,
                                  evnt.donor_pos,
                                  evnt.acceptor_pos
                          FROM misspl_app.misspl_events_", db, "_tx tx
                          JOIN misspl_app.misspl_events_", db, "_events evnt
                          ON tx.gene_tx_id = evnt.gene_tx_id
                          AND ss_type = '", tolower(input$ssTypeInput), "'
                          AND exon_no = ", gsub(' \\((.*?)\\)', '', input$exonInput),
                          cryp_filt,
                          es_filt,
                          " AND tx.tx_id = '", gsub(' \\(Canonical\\)', '', input$txInput), "'
                          ORDER BY evnt.sample_count DESC",
                          event_filt, ";")
    set_table <- dbGetQuery(con, table_query)
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
               missplicing_inframe = ifelse(missplicing_inframe == TRUE, 'yes', ''),
               in_gtex = ifelse(in_gtex == TRUE, 'yes', ''),
               in_sra = ifelse(in_sra == TRUE, 'yes', ''),
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
               missplicing_inframe = ifelse(missplicing_inframe == TRUE, 'yes', ''),
               in_gtex = ifelse(in_gtex == TRUE, 'yes', ''),
               in_intropolis = ifelse(in_intropolis == TRUE, 'yes', ''),
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
        columnDefs = list(list(className = 'dt-center', targets = c(0:5,10:11)),
                          list(className = 'dt-right', targets = c(9))),
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
        style = "bootstrap",
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
