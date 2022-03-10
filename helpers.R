get_genes <- function(db, transcript_type) {
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

get_tx <- function(db, transcript_type, gene_name) {
  switch (db,
          "40K-RNA (hg19)" = {
            tx_query <- paste0("SELECT tx_id || CASE WHEN canonical = 1 THEN ' (Canonical)' ELSE '' END AS display_value,
                             tx_id AS id
                             FROM misspl_app.misspl_events_40k_hg19_tx
                             WHERE gene_name = '",gene_name, "' 
                             AND transcript_type = '",  transcript_type, "'
                             ORDER BY canonical DESC, tx_id;")
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

get_exons <- function(db, transcript_id, transcript_type, ss_type) {
  switch (db,
          "40K-RNA (hg19)" = {
            ex_query <- paste0("SELECT DISTINCT evnt.exon_no || ' (g.' || splice_site_pos || ')' AS display_value, exon_no AS id
              FROM misspl_app.misspl_events_40k_hg19_tx tx
              JOIN misspl_app.misspl_events_40k_hg19_events evnt
              ON tx.gene_tx_id = evnt.gene_tx_id
              AND ss_type = '", ss_type, "'
              AND tx.transcript_type = '", transcript_type, "'
              AND tx.tx_id = '", gsub(' \\(Canonical\\)', '', transcript_id), "' ORDER BY exon_no ASC;")
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

get_tissues <- function() {
  qry <- "SELECT CASE WHEN clinically_accessible THEN CASE WHEN tissue = 'Whole Blood' THEN 'Blood - Whole' ELSE tissue END || '*'
                      ELSE tissue END AS display_value, 
                 tissue_id AS id 
            FROM misspl_app.ref_tissues rt
          ORDER BY clinically_accessible DESC, display_value ;"
  flog.trace(qry)
  res <- dbGetQuery(con, qry)
  return(res)
}

get_misspl_stats <- function(db, ss_type, exon_id, transcript_id, cryp_filt, es_filt, event_filt, tissue_id = NULL, events_limit = NULL) {
  flog.trace(event_filt)
  
  switch (db,
          "40K-RNA (hg19)" = {
            table_query <- paste0("SELECT evnt.splicing_event_class,
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
                                    AND ss_type = '", ss_type, "'
                                    AND exon_no = ", gsub(' \\((.*?)\\)', '', exon_id),
                                  cryp_filt,
                                  es_filt,
                                  " AND tx.tx_id = '", gsub(' \\(Canonical\\)', '', transcript_id), "'
                                    ORDER BY evnt.sample_count DESC",
                                  event_filt, ";")
          },
          "300K-RNA (hg38)" = {
            if (tissue_id == 0) {  # All tissues
              qry <- paste0("SELECT
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
                                  CASE WHEN tms3.tissue_id IS NOT NULL THEN 'LCL, ' ELSE '' END ||
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
                              INNER JOIN misspl_app.ref_exons RE ON
                                  MS.exon_id = RE.exon_id
                                  AND RE.transcript_id = MS.transcript_id 
                              INNER JOIN misspl_app.ref_missplicing_event RME ON
                                  MS.misspl_event_id = RME.misspl_event_id
                              INNER JOIN misspl_app.ref_tx RT ON
                                  MS.transcript_id = RT.transcript_id
                              INNER JOIN misspl_app.ref_splice_sites rss ON
                                  MS.ss_id = rss.ss_id 
                                  AND rss.exon_id = RE.exon_id 
                              WHERE MS.transcript_id = {transcript_id}
                                AND RE.exon_id = {exon_id}
                                AND rss.ss_type = {ss_type} ",
                            cryp_filt,
                            es_filt,
                              " ORDER BY
                                  sample_count DESC ",
                            event_filt, ";")
              table_query <- glue_sql(qry,
                                      events_limit = events_limit,
                                      transcript_id = transcript_id,
                                      exon_id = exon_id,
                                      ss_type = ss_type,
                                      .con = con)
            } else {
              qry <- paste0("SELECT
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
                              INNER JOIN misspl_app.ref_exons RE ON
                                  MS.exon_id = RE.exon_id
                                  AND RE.transcript_id = MS.transcript_id 
                              INNER JOIN misspl_app.ref_missplicing_event RME ON
                                  MS.misspl_event_id = RME.misspl_event_id
                              INNER JOIN misspl_app.ref_tx RT ON
                                  MS.transcript_id = RT.transcript_id
                              INNER JOIN misspl_app.tissue_missplicing_stats TMS ON
                                  MS.misspl_stat_id = TMS.misspl_stat_id
                              INNER JOIN misspl_app.ref_tissues RT2 ON
                                  TMS.tissue_id = RT2.tissue_id
                              INNER JOIN misspl_app.ref_splice_sites rss ON
                                  MS.ss_id = rss.ss_id 
                                  AND rss.exon_id = RE.exon_id 
                              WHERE RT2.tissue_id = {tissue_id}
                                AND MS.transcript_id = {transcript_id}
                                AND RE.exon_id = {exon_id}
                                AND rss.ss_type = {ss_type} ",
                            cryp_filt,
                            es_filt,
                              " ORDER BY
                                  TMS.tissue_sample_count DESC ",
                           event_filt, ";")
              table_query <- glue_sql(qry,
                                     tissue_id = tissue_id,
                                     transcript_id = transcript_id,
                                     exon_id = exon_id,
                                     ss_type = ss_type,
                                     .con = con)
            }
          })

  flog.trace(table_query)
  set_table <- dbGetQuery(con, table_query)
  return(set_table)
}