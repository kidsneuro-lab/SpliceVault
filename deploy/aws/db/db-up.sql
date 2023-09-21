create table misspl_events_40k_hg19_tx
(
    gene_tx_id      integer primary key,
    gene_name       varchar,
    tx_id           varchar,
    canonical       integer,
    strand          varchar,
    assembly        char(4),
    transcript_type varchar
);

create table misspl_events_40k_hg19_events
(
    splice_site_pos         integer,
    ss_type                 varchar,
    exon_no                 integer,
    splicing_event_class    varchar,
    event_rank              integer,
    in_gtex                 boolean,
    in_intropolis           boolean,
    missplicing_inframe     boolean,
    gtex_sample_count       integer,
    intropolis_sample_count integer,
    sample_count            integer,
    gtex_q99_uniq_map_reads integer,
    gtex_max_uniq_map_reads integer,
    intropolis_max_reads    integer,
    gtex_multimap_flag      integer,
    skipped_exons_count     integer,
    skipped_exons_id        varchar,
    cryptic_distance        integer,
    chr                     varchar,
    donor_pos               integer,
    acceptor_pos            integer,
    gene_tx_id              integer
);

create table misspl_events_300k_hg38_tx
(
    gene_tx_id      integer primary key,
    gene_name       varchar,
    tx_id           varchar,
    canonical       integer,
    strand          varchar,
    assembly        char(4),
    transcript_type varchar
);

create table misspl_events_300k_hg38_events
(
    splice_site_pos      integer,
    ss_type              varchar,
    exon_no              integer,
    splicing_event_class varchar,
    event_rank           integer,
    in_gtex              boolean,
    in_sra               boolean,
    missplicing_inframe  boolean,
    gtex_sample_count    integer,
    max_uniq_reads       integer,
    sra_sample_count     integer,
    sample_count         integer,
    skipped_exons_count  integer,
    skipped_exons_id     varchar,
    cryptic_distance     integer,
    chr                  varchar,
    donor_pos            integer,
    acceptor_pos         integer,
    gene_tx_id           integer
);

create table ref_tx
(
    transcript_id   integer primary key,
    gene_name       varchar not null,
    tx_id           varchar not null,
    strand          char    not null,
    canonical       boolean not null,
    transcript_type varchar not null,
    assembly        varchar not null
);

create table ref_exons
(
    exon_id       integer primary key,
    transcript_id integer not null,
    exon_no       integer not null
);

create table ref_splice_sites
(
    ss_id           integer primary key,
    exon_id         integer not null,
    splice_site_pos integer not null,
    ss_type         varchar not null
);

create table ref_missplicing_event
(
    misspl_event_id integer primary key,
    chromosome      varchar not null,
    donor_pos       integer not null,
    acceptor_pos    integer not null,
    assembly        varchar not null
);

create table ref_tissues
(
    tissue_id             integer primary key, 
    tissue                varchar not null,
    num_samples           integer not null,
    tissue_category       varchar not null,
    clinically_accessible boolean not null
);

create table missplicing_stats
(
    misspl_stat_id       integer primary key,
    transcript_id        integer not null,
    exon_id              integer not null,
    ss_id                integer not null,
    misspl_event_id      integer not null,
    splicing_event_class varchar,
    event_rank           integer not null,
    in_gtex              boolean,
    in_sra               boolean,
    missplicing_inframe  boolean not null,
    gtex_sample_count    integer,
    sra_sample_count     integer,
    skipped_exons_count  integer,
    skipped_exons_id     varchar,
    cryptic_distance     integer,
    min_junc_count       integer,
    avg_junc_count       double precision,
    med_junc_count       double precision,
    max_junc_count       integer
);

create table tissue_missplicing_stats
(
    tissue_misspl_stat_id integer primary key,
    misspl_stat_id        integer not null,
    tissue_id             integer not null,
    event_rank            integer not null,
    tissue_sample_count   integer not null,
    min_junc_count        integer not null,
    avg_junc_count        double precision not null,
    max_junc_count        integer not null
);

