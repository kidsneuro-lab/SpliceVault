create table misspl_events_40k_hg19_tx
(
    gene_tx_id      integer generated always as identity unique,
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
    gene_tx_id              integer constraint fk_event_tx_id references misspl_events_40k_hg19_tx (gene_tx_id)
);

create index idx_evnt_gene_tx_id
    on misspl_events_40k_hg19_events (gene_tx_id);

create index idx_evnt_sstype
    on misspl_events_40k_hg19_events (ss_type);

create index idx_tx_gene
    on misspl_events_40k_hg19_tx (gene_name);

create index idx_tx_gene_tx
    on misspl_events_40k_hg19_tx (gene_name, tx_id);

create table misspl_events_300k_hg38_tx
(
    gene_tx_id      integer generated always as identity unique,
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
        constraint fk_300k_hg38_event_tx_id
            references misspl_events_300k_hg38_tx (gene_tx_id)
);

create index idx_300k_hg38_evnt_gene_tx_id
    on misspl_events_300k_hg38_events (gene_tx_id);

create index idx_300k_hg38_tx_gene
    on misspl_events_300k_hg38_tx (gene_name);

create index idx_300k_hg38_tx_gene_tx
    on misspl_events_300k_hg38_tx (gene_name, tx_id);

create table ref_tx
(
    transcript_id   serial constraint ref_tx_pk primary key,
    gene_name       varchar not null,
    tx_id           varchar not null,
    strand          char    not null,
    canonical       boolean not null,
    transcript_type varchar not null,
    assembly        varchar not null,
    constraint ref_tx_un_1 unique (gene_name, tx_id, assembly)
);

create index ref_tx_transcript_type_idx
    on ref_tx (transcript_type);

create table ref_exons
(
    exon_id       serial constraint ref_exons_pk primary key,
    transcript_id integer not null constraint ref_exons_fk references ref_tx on update cascade on delete cascade,
    exon_no       integer not null
);

create table ref_splice_sites
(
    ss_id           serial constraint ref_ss_pk primary key,
    exon_id         integer not null constraint ref_ss_fk_2 references ref_exons on update cascade on delete cascade,
    splice_site_pos integer not null,
    ss_type         varchar not null,
    constraint ref_ss_un_1 unique (exon_id, splice_site_pos, ss_type)
);

create index ref_splice_sites_ss_type_idx
    on ref_splice_sites (ss_type);

create table ref_missplicing_event
(
    misspl_event_id serial constraint ref_misspl_evnt_pk primary key,
    chromosome      varchar not null,
    donor_pos       integer not null,
    acceptor_pos    integer not null,
    assembly        varchar not null,
    constraint ref_misspl_evnt_un_1 unique (chromosome, donor_pos, acceptor_pos, assembly)
);

create table ref_tissues
(
    tissue_id             serial constraint ref_tissues_pk primary key, tissue varchar not null constraint ref_tissues_un_1 unique,
    num_samples           integer not null,
    tissue_category       varchar not null,
    clinically_accessible boolean not null
);

create table missplicing_stats
(
    misspl_stat_id       serial constraint ref_ms_pk primary key,
    transcript_id        integer not null constraint ref_ms_fk_1 references ref_tx on update cascade on delete cascade,
    exon_id              integer not null constraint ref_ms_fk_2 references ref_exons on update cascade on delete cascade,
    ss_id                integer not null constraint ref_ms_fk_3 references ref_splice_sites on update cascade on delete cascade,
    misspl_event_id      integer not null constraint ref_ms_fk_4 references ref_missplicing_event on update cascade on delete cascade,
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

create index missplicing_stats_exon_id_idx
    on missplicing_stats (exon_id);


create table tissue_missplicing_stats
(
    tissue_misspl_stat_id serial constraint ref_tms_pk primary key,
    misspl_stat_id        integer not null constraint ref_tms_fk_1 references missplicing_stats on update cascade on delete cascade,
    tissue_id             integer          not null constraint ref_tms_fk_2 references ref_tissues on update cascade on delete cascade,
    event_rank            integer          not null,
    tissue_sample_count   integer          not null,
    min_junc_count        integer          not null,
    avg_junc_count        double precision not null,
    max_junc_count        integer          not null
);

create index tissue_missplicing_stats_misspl_stat_id_idx
    on tissue_missplicing_stats (misspl_stat_id);