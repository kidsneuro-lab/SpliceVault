-- ============================================================================
-- Performance Optimization Indexes for SpliceVault
-- ============================================================================
-- This script creates indexes to optimize dropdown data retrieval and lookups
-- Run this script against your SpliceVault PostgreSQL database
--
-- Usage:
--   psql -U [username] -d [database_name] -f performance_indexes.sql
--
-- Note: Index creation may take several minutes on large datasets
-- Note: CONCURRENTLY option prevents locking but cannot be used in transaction
-- ============================================================================

-- ============================================================================
-- Indexes for 300K-RNA (hg38) Database Tables
-- ============================================================================

-- Optimize gene name lookups for dropdown population
-- Used by: get_genes() function
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_tx_gene_name_transcript_type 
ON misspl_app.ref_tx(gene_name, transcript_type);

-- Optimize transcript lookups by gene and type
-- Used by: get_tx() function
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_tx_transcript_id_gene_name 
ON misspl_app.ref_tx(transcript_id, gene_name, transcript_type);

-- Additional composite index for canonical transcript prioritization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_tx_gene_canonical 
ON misspl_app.ref_tx(gene_name, transcript_type, canonical DESC, transcript_id);

-- Optimize exon lookups by transcript
-- Used by: get_exons() function
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_exons_transcript_id_exon_no 
ON misspl_app.ref_exons(transcript_id, exon_no);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_exons_exon_id_transcript 
ON misspl_app.ref_exons(exon_id, transcript_id);

-- Optimize splice site lookups
-- Used by: get_exons() function for splice site position retrieval
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_splice_sites_exon_id_ss_type 
ON misspl_app.ref_splice_sites(exon_id, ss_type);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_splice_sites_ss_id 
ON misspl_app.ref_splice_sites(ss_id);

-- Optimize tissue lookups with clinically accessible filter
-- Used by: get_tissues() function
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_tissues_clinically_accessible 
ON misspl_app.ref_tissues(clinically_accessible, tissue);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_tissues_tissue_id 
ON misspl_app.ref_tissues(tissue_id);

-- Optimize missplicing statistics lookups
-- Used by: get_misspl_stats() function
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_stats_transcript_exon_ss 
ON misspl_app.missplicing_stats(transcript_id, exon_id, ss_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_stats_misspl_event_id 
ON misspl_app.missplicing_stats(misspl_event_id);

-- Optimize tissue-specific missplicing statistics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tissue_misspl_stats_misspl_stat_id 
ON misspl_app.tissue_missplicing_stats(misspl_stat_id, tissue_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tissue_misspl_stats_tissue_rank 
ON misspl_app.tissue_missplicing_stats(tissue_id, event_rank);

-- Optimize reference missplicing event lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ref_misspl_event_id 
ON misspl_app.ref_missplicing_event(misspl_event_id);

-- Optimize variant lookup queries for 300K dataset
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_events_300k_events_exon_tx 
ON misspl_app.misspl_events_300k_hg38_events(exon_no, tx_id)
WHERE splicing_event_class = 'normal splicing';

-- ============================================================================
-- Indexes for 40K-RNA (hg19) Database Tables
-- ============================================================================

-- Optimize gene/transcript lookups for hg19 database
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_events_40k_gene_name_tx_type 
ON misspl_app.misspl_events_40k_hg19_tx(gene_name, transcript_type);

-- Optimize transcript lookups with canonical prioritization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_events_40k_tx_id_gene_name 
ON misspl_app.misspl_events_40k_hg19_tx(tx_id, gene_name, transcript_type);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_events_40k_gene_canonical 
ON misspl_app.misspl_events_40k_hg19_tx(gene_name, transcript_type, canonical DESC, tx_id);

-- Optimize event lookups for exon dropdown population
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_misspl_events_40k_gene_tx_id_ss_type 
ON misspl_app.misspl_events_40k_hg19_events(gene_tx_id, ss_type, exon_no);

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Verify indexes were created successfully
DO $$
DECLARE
    index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE schemaname = 'misspl_app'
    AND indexname LIKE 'idx_%';
    
    RAISE NOTICE 'Total performance indexes created: %', index_count;
END $$;

-- Display all indexes on key tables
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'misspl_app'
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ============================================================================
-- Post-Index Creation Maintenance
-- ============================================================================

-- Update table statistics for query planner
ANALYZE misspl_app.ref_tx;
ANALYZE misspl_app.ref_exons;
ANALYZE misspl_app.ref_splice_sites;
ANALYZE misspl_app.ref_tissues;
ANALYZE misspl_app.missplicing_stats;
ANALYZE misspl_app.tissue_missplicing_stats;
ANALYZE misspl_app.ref_missplicing_event;
ANALYZE misspl_app.misspl_events_40k_hg19_tx;
ANALYZE misspl_app.misspl_events_40k_hg19_events;
ANALYZE misspl_app.misspl_events_300k_hg38_events;

-- ============================================================================
-- Performance Testing Queries
-- ============================================================================

-- Test gene name lookup performance
EXPLAIN ANALYZE 
SELECT DISTINCT gene_name 
FROM misspl_app.ref_tx 
WHERE transcript_type = 'refseq' 
ORDER BY gene_name;

-- Test transcript lookup performance
EXPLAIN ANALYZE 
SELECT tx_id || CASE WHEN canonical THEN ' (Canonical)' ELSE '' END AS display_value,
       transcript_id AS id
FROM misspl_app.ref_tx
WHERE transcript_type = 'refseq' 
AND gene_name = 'DMD'
ORDER BY canonical DESC, transcript_id;

-- Test exon lookup performance
EXPLAIN ANALYZE 
SELECT re.exon_no || ' (g.' || rss.splice_site_pos || ')' AS display_value, 
       re.exon_id as id
FROM misspl_app.ref_exons re
JOIN misspl_app.ref_splice_sites rss
  ON re.exon_id = rss.exon_id
  AND rss.ss_type = 'acceptor'
WHERE re.transcript_id = 1234
ORDER BY re.exon_no ASC;

-- Test tissue lookup performance
EXPLAIN ANALYZE 
SELECT CASE WHEN clinically_accessible THEN tissue || '*'
            ELSE tissue END AS display_value, 
       tissue_id AS id 
FROM misspl_app.ref_tissues rt
ORDER BY clinically_accessible DESC, display_value;

-- ============================================================================
-- Index Usage Monitoring
-- ============================================================================

-- Query to monitor index usage over time
-- Run this periodically to ensure indexes are being utilized
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes 
WHERE schemaname = 'misspl_app'
AND indexname LIKE 'idx_%'
ORDER BY idx_scan DESC;

-- ============================================================================
-- Notes
-- ============================================================================
-- 
-- * CONCURRENTLY option allows index creation without locking the table
-- * IF NOT EXISTS prevents errors if indexes already exist
-- * ANALYZE updates statistics for the query planner to use new indexes
-- * Monitor pg_stat_user_indexes to verify indexes are being used
-- * Consider DROP INDEX for unused indexes to save space and maintenance overhead
-- 
-- ============================================================================
