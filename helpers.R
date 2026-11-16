get_genes_uncached <- function(db, transcript_type) {
  switch (db,
          "40K-RNA (hg19)" = {
            qry <- glue_sql("SELECT DISTINCT gene_name FROM misspl_app.misspl_events_40k_hg19_tx
                              WHERE transcript_type = {transcript_type}
                             ORDER BY gene_name",
                            transcript_type = transcript_type,
                            .con = con)
          },
          "300K-RNA (hg38)" = {
            qry <- glue_sql("SELECT DISTINCT gene_name 
                              FROM misspl_app.ref_tx 
                              WHERE transcript_type = {transcript_type}
                            ORDER BY gene_name",
                          transcript_type = transcript_type,
                          .con = con)
          })
  flog.trace(qry)
  genes <- dbGetQuery(con, qry)
  return(genes)
}

get_tx_uncached <- function(db, transcript_type, gene_name) {
  switch (db,
          "40K-RNA (hg19)" = {
            tx_query <- glue_sql("SELECT tx_id || CASE WHEN canonical = 1 THEN ' (Canonical)' ELSE '' END AS display_value,
                             tx_id AS id
                             FROM misspl_app.misspl_events_40k_hg19_tx
                             WHERE gene_name = {gene_name}
                             AND transcript_type = {transcript_type}
                             ORDER BY canonical DESC, tx_id;",
                                 gene_name = gene_name,
                                 transcript_type = transcript_type,
                                 .con = con)
          },
          "300K-RNA (hg38)" = {
            tx_query <-
              glue_sql(
                "SELECT tx_id || CASE WHEN canonical THEN ' (Canonical)' ELSE '' END AS display_value,
                                            transcript_id AS id
                                       FROM misspl_app.ref_tx
                                      WHERE transcript_type = {transcript_type} AND gene_name = {gene_name}
                                     ORDER BY canonical DESC, transcript_id;",
                transcript_type = transcript_type,
                gene_name = gene_name,
                .con = con
              )
          })
  flog.trace(tx_query)
  txs <- dbGetQuery(con, tx_query)
  return(txs)
}

get_exons_uncached <- function(db, transcript_id, transcript_type, ss_type) {
  switch (db,
          "40K-RNA (hg19)" = {
            ex_query <- glue_sql("SELECT DISTINCT evnt.exon_no || ' (g.' || splice_site_pos || ')' AS display_value, exon_no AS id
              FROM misspl_app.misspl_events_40k_hg19_tx tx
              JOIN misspl_app.misspl_events_40k_hg19_events evnt
              ON tx.gene_tx_id = evnt.gene_tx_id
              AND ss_type = {ss_type}
              AND tx.transcript_type = {transcript_type}
              AND tx.tx_id = {tx_id} ORDER BY exon_no ASC;",
                                 ss_type = ss_type,
                                 transcript_type = transcript_type,
                                 tx_id = gsub(' \\(Canonical\\)', '', transcript_id),
                                 .con = con)
            ex <- dbGetQuery(con, ex_query)
          },
          "300K-RNA (hg38)" = {
            ex_query <- glue_sql("SELECT re.exon_no || ' (g.' || rss.splice_site_pos || ')' AS display_value, re.exon_id as id
                                      FROM misspl_app.ref_exons re
                                    JOIN misspl_app.ref_splice_sites rss
                                      ON re.exon_id = rss.exon_id
                                      AND rss.ss_type = {ss_type}
                                     WHERE re.transcript_id = {transcript_id}
                                    ORDER BY re.exon_no ASC;",
                                 ss_type = ss_type,
                                 transcript_id = transcript_id,
                                 .con = con)
            ex <- dbGetQuery(con, ex_query)
          })
  flog.trace(ex_query)
  return(ex)
}

get_tissues_uncached <- function() {
  qry <- "SELECT CASE WHEN clinically_accessible THEN CASE WHEN tissue = 'Whole Blood' THEN 'Blood - Whole' ELSE tissue END || '*'
                      ELSE tissue END AS display_value, 
                 tissue_id AS id 
            FROM misspl_app.ref_tissues rt
          ORDER BY clinically_accessible DESC, display_value ;"
  flog.trace(qry)
  res <- dbGetQuery(con, qry)
  return(res)
}

# Dropdown lists, cached for the life of the app process and shared by every
# session. They only change when the misspl_app schema is reloaded, which goes
# with a redeploy and so a fresh process; nothing expires them before that.
# memoise() keeps only results: a query that fails is run again next time.
# Gene and tissue lists are few (a gene list per dataset and transcript type,
# one tissue list); transcript and exon lists grow with the genes users pick,
# so their cache is bounded and drops the least recently used first.
reference_cache <- cachem::cache_mem(max_size = Inf)
lookup_cache <- cachem::cache_mem(max_size = 50 * 1024^2)

get_genes <- memoise(get_genes_uncached, cache = reference_cache)
get_tissues <- memoise(get_tissues_uncached, cache = reference_cache)
get_tx <- memoise(get_tx_uncached, cache = lookup_cache)
get_exons <- memoise(get_exons_uncached, cache = lookup_cache)

# Empties every dropdown cache, as a fresh process would start.
reset_reference_caches <- function() {
  reference_cache$reset()
  lookup_cache$reset()
  invisible()
}

# max_cryptic, max_skipped and limit are numbers, or NULL to leave that filter
# off ("Show all"). They come from the browser, so they are converted to
# integers and bound, never pasted into the SQL.
get_misspl_stats <- function(db, ss_type, exon_id, transcript_id, max_cryptic = NULL, max_skipped = NULL, limit = NULL, tissue_id = NULL, events_limit = NULL) {
  table_query <- misspl_stats_query(db, ss_type, exon_id, transcript_id, max_cryptic, max_skipped,
                                    limit, tissue_id, events_limit)
  flog.trace(table_query)
  dbGetQuery(con, table_query)
}

# The events table SQL for get_misspl_stats(), also used by
# tests/benchmark/query_plans.R to review its query plans.
misspl_stats_query <- function(db, ss_type, exon_id, transcript_id, max_cryptic = NULL, max_skipped = NULL, limit = NULL, tissue_id = NULL, events_limit = NULL) {
  cryp_filt <- if (is.null(max_cryptic)) SQL("") else
    glue_sql(" AND (ABS(cryptic_distance) <= {max_cryptic} OR cryptic_distance IS NULL)",
             max_cryptic = as.integer(max_cryptic), .con = con)
  es_filt <- if (is.null(max_skipped)) SQL("") else
    glue_sql(" AND (skipped_exons_count <= {max_skipped} OR skipped_exons_count IS NULL)",
             max_skipped = as.integer(max_skipped), .con = con)
  event_filt <- if (is.null(limit)) SQL("") else
    glue_sql(" LIMIT {limit}", limit = as.integer(limit), .con = con)
  flog.trace(event_filt)

  switch (db,
          "40K-RNA (hg19)" = {
            table_query <- glue_sql("SELECT evnt.splicing_event_class,
                                          CASE WHEN evnt.missplicing_inframe = TRUE THEN 'Yes' ELSE 'No' END AS missplicing_inframe,
                                          CASE WHEN evnt.in_gtex = TRUE THEN 'Yes' ELSE 'No' END AS in_gtex,
                                          CASE WHEN evnt.in_intropolis = TRUE THEN 'Yes' ELSE 'No' END AS in_intropolis,
                                          evnt.skipped_exons_id,
                                          evnt.cryptic_distance,
                                          evnt.gtex_sample_count,
                                          evnt.intropolis_sample_count,
                                          evnt.gtex_max_uniq_map_reads,
                                          evnt.sample_count,
                                          evnt.chr,
                                          evnt.donor_pos,
                                          evnt.acceptor_pos
                                    FROM misspl_app.misspl_events_40k_hg19_tx tx
                                    JOIN misspl_app.misspl_events_40k_hg19_events evnt
                                    ON tx.gene_tx_id = evnt.gene_tx_id
                                    AND ss_type = {ss_type}
                                    AND exon_no = {exon_no}{cryp_filt}{es_filt} AND tx.tx_id = {tx_id}
                                    ORDER BY evnt.sample_count DESC{event_filt};",
                                    ss_type = ss_type,
                                    exon_no = as.integer(gsub(' \\((.*?)\\)', '', exon_id)),
                                    cryp_filt = cryp_filt,
                                    es_filt = es_filt,
                                    tx_id = gsub(' \\(Canonical\\)', '', transcript_id),
                                    event_filt = event_filt,
                                    .con = con)
          },
          "300K-RNA (hg38)" = {
            if (tissue_id == 0) {  # All tissues
              qry <- "SELECT
                                  MS.splicing_event_class,
                                  CASE WHEN MS.missplicing_inframe = TRUE THEN 'Yes' ELSE 'No' END AS missplicing_inframe,
                                  CASE WHEN MS.in_gtex = TRUE THEN 'Yes' ELSE 'No' END AS in_gtex,
                                  CASE WHEN MS.in_sra = TRUE THEN 'Yes' ELSE 'No' END AS in_sra,
                                  MS.skipped_exons_id,
                                  MS.cryptic_distance,
                                  MS.gtex_sample_count,
                                  MS.sra_sample_count,
                                  MS.max_junc_count,
                                  MS.gtex_sample_count + MS.sra_sample_count AS sample_count,
                                  CASE WHEN tms1.tissue_id IS NOT NULL THEN 'B, ' ELSE '' END ||
                                  CASE WHEN tms2.tissue_id IS NOT NULL THEN 'F, ' ELSE '' END ||
                                  CASE WHEN tms3.tissue_id IS NOT NULL THEN 'L, ' ELSE '' END ||
                                  CASE WHEN tms4.tissue_id IS NOT NULL THEN 'M, ' ELSE '' END AS clin_access_tissues,
                                  RME.chromosome AS chr,
                                  RME.donor_pos,
                                  RME.acceptor_pos
                              FROM
                                  misspl_app.missplicing_stats MS
                              LEFT JOIN misspl_app.tissue_missplicing_stats tms1 ON -- Whole Blood
                                  MS.misspl_stat_id = tms1.misspl_stat_id 
                                  AND tms1.event_rank <= {events_limit}
                                  AND tms1.tissue_id = 5
                              LEFT JOIN misspl_app.tissue_missplicing_stats tms2 ON -- Fibroblasts
                                  MS.misspl_stat_id = tms2.misspl_stat_id 
                                  AND tms2.event_rank <= {events_limit}
                                  AND tms2.tissue_id = 4
                              LEFT JOIN misspl_app.tissue_missplicing_stats tms3 ON -- EBV-transformed lymphocytes
                                  MS.misspl_stat_id = tms3.misspl_stat_id 
                                  AND tms3.event_rank <= {events_limit}
                                  AND tms3.tissue_id = 6
                              LEFT JOIN misspl_app.tissue_missplicing_stats tms4 ON -- Muscle - Skeletal
                                  MS.misspl_stat_id = tms4.misspl_stat_id 
                                  AND tms4.event_rank <= {events_limit}
                                  AND tms4.tissue_id = 30
                              INNER JOIN misspl_app.ref_missplicing_event RME ON
                                  MS.misspl_event_id = RME.misspl_event_id
                              INNER JOIN misspl_app.ref_splice_sites rss ON
                                  MS.ss_id = rss.ss_id
                                  AND rss.exon_id = MS.exon_id
                              WHERE MS.transcript_id = {transcript_id}
                                AND MS.exon_id = {exon_id}
                                AND rss.ss_type = {ss_type} {cryp_filt}{es_filt} ORDER BY
                                  sample_count DESC {event_filt};"
              table_query <- glue_sql(qry,
                                      events_limit = events_limit,
                                      transcript_id = transcript_id,
                                      exon_id = exon_id,
                                      ss_type = ss_type,
                                      cryp_filt = cryp_filt,
                                      es_filt = es_filt,
                                      event_filt = event_filt,
                                      .con = con)
            } else {
              qry <- "SELECT
                                  MS.splicing_event_class,
                                  CASE WHEN MS.missplicing_inframe = TRUE THEN 'Yes' ELSE 'No' END AS missplicing_inframe,
                                  CASE WHEN MS.in_gtex = TRUE THEN 'Yes' ELSE 'No' END AS in_gtex,
                                  MS.skipped_exons_id,
                                  MS.cryptic_distance,
                                  TMS.tissue_sample_count AS sample_count,
                                  TMS.max_junc_count,
                                  RME.chromosome AS chr,
                                  RME.donor_pos,
                                  RME.acceptor_pos
                              FROM
                                  misspl_app.missplicing_stats MS
                              INNER JOIN misspl_app.ref_missplicing_event RME ON
                                  MS.misspl_event_id = RME.misspl_event_id
                              INNER JOIN misspl_app.tissue_missplicing_stats TMS ON
                                  MS.misspl_stat_id = TMS.misspl_stat_id
                              INNER JOIN misspl_app.ref_splice_sites rss ON
                                  MS.ss_id = rss.ss_id
                                  AND rss.exon_id = MS.exon_id
                              WHERE TMS.tissue_id = {tissue_id}
                                AND MS.transcript_id = {transcript_id}
                                AND MS.exon_id = {exon_id}
                                AND rss.ss_type = {ss_type} {cryp_filt}{es_filt} ORDER BY
                                  TMS.tissue_sample_count DESC {event_filt};"
              table_query <- glue_sql(qry,
                                     tissue_id = tissue_id,
                                     transcript_id = transcript_id,
                                     exon_id = exon_id,
                                     ss_type = ss_type,
                                     cryp_filt = cryp_filt,
                                     es_filt = es_filt,
                                     event_filt = event_filt,
                                     .con = con)
            }
          })
  table_query
}

get_variant_data_restapi <- function(mode, variant, splicesite = NULL){
  # Trim any accidental whitespaces around the variant
  variant <- trimws(variant)
  
  flog.debug(paste("mode:", mode))
  flog.debug(paste("variant:", variant))
  flog.debug(paste("splicesite:", splicesite))
  
  
  #TODO add code to activate this when generate table is pressed and variant input selected
  
  if(mode == "Variant"){
    refseq_transcript <- stringr::str_extract_all(variant, "NM_[0-9]+\\.[0-9]+")[[1]][1]
    ensembl_transcript <- stringr::str_extract_all(variant, "ENST[0-9]+\\.[0-9]+")[[1]][1]
    server <- "https://rest.ensembl.org"
    
    if(!is.na(refseq_transcript)){
      chosen_transcript <- refseq_transcript
      chosen_transcript_no_ver <- stringr::str_extract_all(chosen_transcript, "NM_[0-9]+")[[1]][1]
      variant <- stringr::str_replace(variant,chosen_transcript,chosen_transcript_no_ver)
      transcript <- "refseq=1"
    }else if(!is.na(ensembl_transcript)){
      chosen_transcript <- ensembl_transcript
      chosen_transcript_no_ver <- stringr::str_split(chosen_transcript, "\\.")[[1]][1]
      transcript <- paste0("transcript_id=",chosen_transcript_no_ver)
    }else{
      #stop("Please enter a valid ENSEMBL or RefSeq transcript with the current transcript version number (e.g. NM_004006.4).")
      error_text <- paste0("No transcript accession matching '",variant,"' identified. Please enter a valid ENSEMBL or RefSeq transcript (e.g. NM_004006.3).")
      return(list(error_text,"error",1000,""))
    }
    
    ext <- paste0("/vep/human/hgvs/",variant,"?")
    
    call <- paste0(server,
                   ext,
                   "content-type=application/json",
                   "&numbers=1&",transcript)
    
    flog.debug(call)
    
    r <- GET(call)
    
    if(length(content(r)$error) > 0){
      
      if(stringr::str_detect(content(r)$error,"does not match reference allele")){
        correct_ref <- stringr::str_extract_all(content(r)$error,"\\([A,C,G,T]\\)")[[1]][1]
        supplied_ref <- stringr::str_extract_all(content(r)$error,"\\([A,C,G,T]\\)")[[1]][2]
        error_text <- paste0("Incorrect reference allele provided: ",supplied_ref,". ",
                        "Correct reference allele is: ", correct_ref,". ",
                        "Ensure you have selected the correct transcript. You entered: ",
                        chosen_transcript)
        return(list(error_text,"error",1000,""))
      }
      
      if(stringr::str_detect(content(r)$error,"Could not get a Transcript object for")){
        error_text <- paste0("No transcript accession matching ",chosen_transcript,
                             " identified. Please enter a valid ENSEMBL or RefSeq transcript.(e.g. NM_004006.3)")
        
        return(list(error_text,"error",1000,""))
      }
      
      if(stringr::str_detect(content(r)$error,"Unable to map the cDNA coordinates")){
        error_text <- paste0("Unable to map the cDNA coordinates for '",chosen_transcript_no_ver,
                             "' Please double check your input.")
        
        return(list(error_text,"error",1000,""))
      } else {
        error_text <- paste0("An unknown error occurred. Please double check your input: '",variant,"'.")
        
        return(list(error_text,"error",1000,""))
      }
      
    }
    
    #stop_for_status(r)

    #gene, transcript, exon, strand, splicesite
    
    for(i in seq(1,length(content(r)[[1]]$transcript_consequences))){
      if(!is.na(stringr::str_extract_all(content(r)[[1]]$transcript_consequences[[i]]$transcript_id,
                                         chosen_transcript_no_ver)[[1]][1])){
        api_data <- content(r)[[1]]$transcript_consequences[[i]]
      }
    }
    
    gene <- api_data$gene_symbol
    
    transcript <- stringr::str_split(chosen_transcript,"\\.")[[1]][1]
    
    message(variant)
    
    if(is.na(stringr::str_match(variant, pattern = "\\+|\\-"))){
      exon <- stringr::str_split(api_data$exon,"\\/")[[1]][1]
      var_pos <- content(r)[[1]]$start

      qry <- "SELECT ev.ss_type, ev.splice_site_pos, ev.exon_no, ev.gene_tx_id, tx.tx_id
                FROM misspl_app.misspl_events_300k_hg38_events ev
              JOIN misspl_app.misspl_events_300k_hg38_tx tx
                ON ev.gene_tx_id = tx.gene_tx_id
                WHERE splicing_event_class = 'normal splicing'
                AND exon_no = {exon_id}
                AND tx_id = {transcript};"
      
      flog.trace(qry)
      
      table_query <- glue_sql(qry,
                              transcript_id = transcript,
                              exon_id = exon,
                              .con = con)
      
      res <- dbGetQuery(con, table_query)
      
      res <- as.data.table(res)
      
      res$diff <- res$splice_site_pos - var_pos
      
      splicesite_raw <- res[,ss_type,diff][order(abs(diff))][[1,2]]
      
      splicesite <- str_to_title(splicesite_raw)
      
    }else{
      if(!is.na(stringr::str_match(variant, pattern = "\\+"))){
        exon <- stringr::str_split(api_data$intron,"\\/")[[1]][1]
        splicesite <- "Donor"
      }else if(!is.na(stringr::str_match(variant, pattern = "\\-"))){
        exon <- as.numeric(stringr::str_split(api_data$intron,"\\/")[[1]][1])+1
        splicesite <- "Acceptor"
      }
    }
    
    list(gene, transcript, exon, splicesite)
  }
}

get_variant_sql_codes <- function(ss_type = NULL, exon_id = NULL, transcript_id = NULL) {
  qry <- "SELECT rt.transcript_id, re.exon_id, rss.ss_id
            FROM misspl_app.ref_tx rt
            JOIN misspl_app.ref_exons re
              ON rt.transcript_id = re.transcript_id
              AND re.exon_no = {exon_id}
            JOIN misspl_app.ref_splice_sites rss
              ON re.exon_id = rss.exon_id
              AND rss.ss_type = {ss_type}
            WHERE rt.tx_id = {transcript_id};"
  flog.trace(qry)
  
  table_query <- glue_sql(qry,
                          transcript_id = transcript_id,
                          exon_id = exon_id,
                          ss_type = ss_type,
                          .con = con)
  
  res <- dbGetQuery(con, table_query)
  return(as.list(res))
}

# The title shown above the events table and at the top of its exports. It
# describes the query: how many events, the dataset, transcript, tissue (NULL
# for all tissues), gene, splice site and exon, then the exon skipping and
# cryptic filters that are on (a NULL maximum means "Show all"). A NULL
# events_no means "Show all events". The spacing is kept exactly as users
# have always seen it.
events_table_title <- function(db, transcript, gene, ss_type, exon, events_no = NULL,
                               max_skipped = NULL, max_cryptic = NULL, tissue = NULL) {
  settings <- if (is.null(max_cryptic) && is.null(max_skipped)) {
    ''
  } else if (is.null(max_cryptic)) {
    paste0(" (max ", max_skipped, " exons skipped)")
  } else if (is.null(max_skipped)) {
    paste0(" (cryptics within +/-", max_cryptic, ")")
  } else {
    paste0(" (max ", max_skipped, " exons skipped, cryptics within +/-", max_cryptic, " nt)")
  }
  events <- if (is.null(events_no)) "all" else paste("top ", events_no)
  tissue <- if (is.null(tissue)) "" else paste0(" [", tissue, "] ")
  paste0("Showing ", events,
         " unannotated events in ", db,
         " for ", gsub(' \\(Canonical\\)', '', transcript), " ",
         tissue,
         "(", gene, ")",
         " ", ss_type, " ", exon,
         settings)
}

# How the events table shows each dataset's columns: the headers, DT column
# definitions and the genome build for IGV links. 300K-RNA (hg38) drops its
# SRA and accessible tissue columns when one tissue is selected.
events_table_columns <- function(db, tissue_selected) {
  tick <- function(targets) list(
    targets = targets,
    render = JS(
      "function(data, type, row, meta) {",
      "return data == 'Yes' ? '<span>&#10003;</span>' : '';",
      "}"))
  switch(db,
         "300K-RNA (hg38)" = if (!tissue_selected) {
           list(colnames = c('Event', 'Same Frame?', 'GTEx?', 'SRA?', 'Skipped Exons', 'Cryptic Position',
                             'Samples (GTEx)', 'Samples (SRA)', 'Max Reads (GTEx)', 'Total Samples', 'Accessible Tissues (GTEx)', 'Splice Junction', 'IGV'),
                columnDefs = list(list(className = 'dt-center', targets = c(0:5,10:12)),
                                  list(className = 'dt-right', targets = c(6:9)),
                                  tick(c(1,2,3)),
                                  list(
                                    targets = 10,
                                    render = JS(
                                      "function(data, type, row, meta) {",
                                      "return data.trim().charAt(data.trim().length-1) == ',' ? data.trim().substr(0, data.trim().length - 1) : data;",
                                      "}"))),
                genome = 'hg38')
         } else {
           list(colnames = c('Event', 'Same Frame?', 'GTEx?', 'Skipped Exons', 'Cryptic Position',
                             'Samples (GTEx)', 'Max Reads (GTEx)', 'Splice Junction', 'IGV'),
                columnDefs = list(list(className = 'dt-center', targets = c(0:4,6:8)),
                                  list(className = 'dt-right', targets = c(5)),
                                  tick(c(1,2))),
                genome = 'hg38')
         },
         "40K-RNA (hg19)" = list(
           colnames = c('Event', 'Same Frame?', 'GTEx?', 'Intropolis?', 'Skipped Exons', 'Cryptic Position',
                        'Samples (GTEx)', 'Samples (Intropolis)', 'Max Reads (GTEx)', 'Total Samples', 'Splice Junction', 'IGV'),
           columnDefs = list(list(className = 'dt-center', targets = c(0:5,10:11)),
                             list(className = 'dt-right', targets = c(9)),
                             tick(c(1,2,3))),
           genome = 'hg19'))
}

# Turns events from get_misspl_stats() into the rows the events table shows,
# for either dataset: the splice junction and its IGV link for the given
# genome build, sample counts with their percentage of the annotated event's
# samples, "annotated" for "normal" splicing and a "+" before positive cryptic
# distances.
format_events <- function(rows, genome) {
  ann_samples <- rows %>% filter(splicing_event_class == 'normal splicing') %>% pull(sample_count)

  rows %>%
    rowwise() %>%
    mutate(start = min(donor_pos, acceptor_pos),
           end = max(donor_pos, acceptor_pos)) %>% ungroup() %>%
    mutate(sj = paste0(paste(chr, paste(start, end, sep = '-'), sep = ':')),
           samples_prop = scales::percent(sample_count / ann_samples, accuracy = 0.1)) %>%
    rowwise() %>%
    mutate(splicing_event_class = gsub('normal', 'annotated', splicing_event_class),
           igv = gsub("amp;","",tags$a(href=paste0("http://localhost:60151/goto?locus=", sj, "&genome=", genome), "link")),
           cryptic_distance = ifelse(cryptic_distance > 0,
                                     paste0('+', as.character(cryptic_distance)),
                                     as.character(cryptic_distance)),
           sample_count = paste0(sample_count, ' (', samples_prop, ')')) %>%
    select(-chr, -donor_pos, -acceptor_pos, -start, -end, -samples_prop)
}
