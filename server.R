
server <- function(input, output, session) {

  # change gene name options based on selected database and transcript type. default to prior selected gene name if available
  observeEvent({
    input$txTypeInput
  }, {
    if (input$txTypeInput == 'Ensembl') {
      genenames <- gene_names_40k_ensembl
    } else if (input$txTypeInput == 'RefSeq') {
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

  #get list of transcripts for select box based on selected gene
  observeEvent({input$geneInput
                input$txTypeInput
                },{
    tx_query <- paste0("SELECT tx_id || CASE WHEN canonical = 1 THEN ' (Canonical)' ELSE '' END AS display_value,
                                     gene_tx_id
                                     FROM misspl_app.misspl_events_40k_hg19_tx
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
  observeEvent({input$txTypeInput
                input$txInput},{
    ex_query <- paste0("SELECT DISTINCT evnt.exon_no || ' (g.' || splice_site_pos || ')' AS display_value, exon_no AS exon_no
    FROM misspl_app.misspl_events_40k_hg19_tx tx
    JOIN misspl_app.misspl_events_40k_hg19_events evnt
    ON tx.gene_tx_id = evnt.gene_tx_id
    AND ss_type = 'donor'
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
    updateSliderInput(session, "cssInput", value=600)
    updateCheckboxInput(session=session, inputId="allevents", value = FALSE)
    updateCheckboxInput(session=session, inputId="allcryptics", value = FALSE)
  })
  
  # UI - OUTCOME - 3 ---------------------------------------------------
  
  output$title_panel <- renderText({
    "Mis-Splicing Events Table"
  })
  
  observeEvent(input$confirm, {
    if (isolate(input$allcryptics) == TRUE) {
      settings = ''
    } else if (isolate(input$allcryptics) == FALSE) {
      settings = paste0(" (cryptics within +/-", isolate(input$cssInput), ")")
    } 
    
    if (isolate(input$allevents) == TRUE) {
      events = "all"
    } else {
      events  = paste("top ", isolate(input$eventsNoInput))
    }
    output$table_title <- renderText(paste0("Showing ", events, 
                                            " unannotated cryptic donors in 40K-RNA (hg19) for ", 
                                            gsub(' \\(Canonical\\)', '', isolate(input$txInput)),
                                            "(",isolate(input$geneInput), ")",
                                            " Donor " ,isolate(input$exonInput),
                                            settings ))
    
  })
  
  table_ms <- eventReactive(input$confirm, {
    db = '40k_hg19'
    second = 'intropolis'
    third = 'gtex_max_uniq_map_reads'
    set_colnames = c('Event', 'Same Frame?', 'GTEx?', 'Intropolis?', 'Cryptic Distance', 
                       'Samples (GTEx)', 'Samples (Intropolis)', 'Max Reads (GTEx)', 'Total Samples', 'Splice Junction', 'IGV')
    genome = 'hg19'
    if (input$allcryptics == FALSE) {
      cryp_filt = paste0(" AND (ABS(cryptic_distance) <= ", gsub('\\+/-| nt', '', input$cssInput), " OR cryptic_distance IS NULL)")
    } else {
      cryp_filt = ""
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
                          AND ss_type = 'donor'
                          AND exon_no = ", gsub(' \\((.*?)\\)', '', input$exonInput),
                          cryp_filt,
                          " AND tx.tx_id = '", gsub(' \\(Canonical\\)', '', input$txInput), "'
                          ORDER BY evnt.sample_count DESC",
                          event_filt, ";")
    set_table <- dbGetQuery(con, table_query)
    ann_samples <- set_table %>% filter(splicing_event_class == 'normal splicing') %>% pull(sample_count)

    set_table <- set_table %>% 
      filter(!grepl('skipping', splicing_event_class)) %>%
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
      select(-chr, -donor_pos, -acceptor_pos, -start, -end, -samples_prop, -skipped_exons_id)

    
    if (isolate(input$allcryptics) == TRUE) {
      settings = ''
    } else if (isolate(input$allcryptics) == FALSE) {
      settings = paste0(" (cryptics within +/-", isolate(input$cssInput), ")")
    } 
    if (isolate(input$allevents) == TRUE) {
      events = "all"
    } else {
      events  = paste("top ", isolate(input$eventsNoInput))
    }
    title_panel <- paste0("Showing ", events, 
                          " unannotated events in 40K-RNA (hg19) for ",
                          gsub(' \\(Canonical\\)', '', isolate(input$txInput)),
                          "(",isolate(input$geneInput), ")",
                          " Donor " ,isolate(input$exonInput),
                          settings )
    datatable(
      set_table,
      rownames = FALSE,
      escape = FALSE,
      extensions = "Buttons",
      colnames = set_colnames,
      class = 'cell-border stripe',
      options = list(
        columnDefs = list(list(className = 'dt-center', targets = c(0:4,9:10)),
                          list(className = 'dt-right', targets = c(8))),
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
