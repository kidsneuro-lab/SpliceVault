-- For misspl_events_40k_hg19_events table
CREATE INDEX idx_evnt_sstype
    ON misspl_events_40k_hg19_events (ss_type);

CREATE INDEX idx_tx_gene
    ON misspl_events_40k_hg19_tx (gene_name);

CREATE INDEX idx_tx_gene_tx
    ON misspl_events_40k_hg19_tx (gene_name, tx_id);

ALTER TABLE misspl_events_40k_hg19_events
ADD CONSTRAINT fk_event_tx_id 
FOREIGN KEY (gene_tx_id) 
REFERENCES misspl_events_40k_hg19_tx(gene_tx_id);

-- For misspl_events_300k_hg38_events table
CREATE INDEX idx_300k_hg38_tx_gene
    ON misspl_events_300k_hg38_tx (gene_name);

CREATE INDEX idx_300k_hg38_tx_gene_tx
    ON misspl_events_300k_hg38_tx (gene_name, tx_id);

ALTER TABLE misspl_events_300k_hg38_events
ADD CONSTRAINT fk_300k_hg38_event_tx_id 
FOREIGN KEY (gene_tx_id) 
REFERENCES misspl_events_300k_hg38_tx(gene_tx_id);

-- For ref_tx table
CREATE INDEX ref_tx_transcript_type_idx
    ON ref_tx (transcript_type);

-- For ref_exons table
ALTER TABLE ref_exons
ADD CONSTRAINT ref_exons_fk 
FOREIGN KEY (transcript_id) 
REFERENCES ref_tx 
ON UPDATE CASCADE ON DELETE CASCADE;

-- For ref_splice_sites table
CREATE INDEX ref_splice_sites_ss_type_idx
    ON ref_splice_sites (ss_type);

ALTER TABLE ref_splice_sites
ADD CONSTRAINT ref_ss_fk_2 
FOREIGN KEY (exon_id) 
REFERENCES ref_exons 
ON UPDATE CASCADE ON DELETE CASCADE;

-- For missplicing_stats table
CREATE INDEX missplicing_stats_exon_id_idx
    ON missplicing_stats (exon_id);

ALTER TABLE missplicing_stats
ADD CONSTRAINT ref_ms_fk_1 
FOREIGN KEY (transcript_id) 
REFERENCES ref_tx 
ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE missplicing_stats
ADD CONSTRAINT ref_ms_fk_2 
FOREIGN KEY (exon_id) 
REFERENCES ref_exons 
ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE missplicing_stats
ADD CONSTRAINT ref_ms_fk_3 
FOREIGN KEY (ss_id) 
REFERENCES ref_splice_sites 
ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE missplicing_stats
ADD CONSTRAINT ref_ms_fk_4 
FOREIGN KEY (misspl_event_id) 
REFERENCES ref_missplicing_event 
ON UPDATE CASCADE ON DELETE CASCADE;

-- For tissue_missplicing_stats table
ALTER TABLE tissue_missplicing_stats
ADD CONSTRAINT ref_tms_fk_1 
FOREIGN KEY (misspl_stat_id) 
REFERENCES missplicing_stats 
ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE tissue_missplicing_stats
ADD CONSTRAINT ref_tms_fk_2 
FOREIGN KEY (tissue_id) 
REFERENCES ref_tissues 
ON UPDATE CASCADE ON DELETE CASCADE;