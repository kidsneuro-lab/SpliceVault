# Event query plans and index review

Query plans for the events table queries on the full-size production
database (PostgreSQL 13), before and after #53 removed joins that added nothing
to the 300K-RNA (hg38) queries. Full plans and SQL are in
[query_plans/before.md](query_plans/before.md) and
[query_plans/after.md](query_plans/after.md); regenerate them with
`Rscript tests/benchmark/query_plans.R <label>` (see the script header).

Each query ran with every "Show all" box ticked, for CNN2 (NM_001303501 exon 2
Donor, Whole Blood for one tissue) and TTN (NM_001267550 exon 48 Acceptor, the
TTN splice site with the most events; Muscle - Skeletal for one tissue).

## Before and after

Buffers are shared pages touched by the last (warm) run. Times are the three
runs, in ms.

| Query | Buffers before | Buffers after | Times before | Times after |
|---|---|---|---|---|
| 40K-RNA (hg19), CNN2 | 1843 | 1842 | 32.5, 29.8, 29.6 | 31.4, 44.7, 28.9 |
| 300K-RNA (hg38) all tissues, CNN2 | 3613 | 3227 | 575.2, 3.3, 3.1 | 2.8, 2.5, 2.2 |
| 300K-RNA (hg38) one tissue, CNN2 | 1457 | 1049 | 1.6, 1.7, 1.7 | 1.6, 1.4, 1.4 |
| 40K-RNA (hg19), TTN | 2019 | 2019 | 30.5, 34.7, 32.5 | 36.9, 33.0, 39.2 |
| 300K-RNA (hg38) all tissues, TTN | 7809 | 6464 | 852.5, 5.4, 5.4 | 6.8, 4.6, 4.5 |
| 300K-RNA (hg38) one tissue, TTN | 3862 | 2443 | 4.0, 5.0, 10.8 | 2.9, 3.7, 3.0 |

- Dropping the `ref_tx`, `ref_exons` and `ref_tissues` joins cut the pages the
  300K-RNA (hg38) queries touch by 11% (all tissues) to 37% (one tissue), and
  removed the per-row sequential scan of `ref_tissues` from the one-tissue
  query. The 40K-RNA (hg19) query did not change.
- Warm, every query finishes in under 45 ms. The cost users feel is the cold
  run: the first 300K-RNA (hg38) all-tissues query for a splice site took
  575 ms (CNN2) and 852 ms (TTN), reading pages from disk. The "after" runs
  followed straight on from the "before" runs, so their caches were already
  warm and these numbers do not show a cold-run change. Fewer pages touched
  means fewer to read cold.

## Where the remaining work goes

- **40K-RNA (hg19)**: `misspl_events_40k_hg19_tx` has no index on `tx_id`
  alone (the existing `idx_tx_gene_tx` leads with `gene_name`, which the query
  does not filter on), so every events table does a parallel sequential scan of
  its 196K rows: about 1830 of the query's 1840 to 2020 pages and 21 of its
  30 ms. The events lookup then reads every 40K event for the transcript and
  filters by splice site type and exon: for TTN, 10,433 rows read to keep 71.
- **300K-RNA (hg38) all tissues**: the four `tissue_missplicing_stats` LEFT
  JOINs that build the accessible tissues column each look up every event
  again: for TTN 192 events, 4 lookups each, 4732 of the query's 6464 pages.
  One lookup per event (one join with a `tissue_id IN (4, 5, 6, 30)` filter
  and a `bool_or` per tissue, or `EXISTS` subqueries) would read about a
  quarter of that. This is an app change, not an index, and is left as a
  follow-up.
- Everything else is primary key or single-index lookups returning the rows it
  needs.

## Index recommendations for the database owner

1. **`misspl_events_40k_hg19_tx (tx_id)`**, the main recommendation. It turns
   the parallel sequential scan above into an index lookup; expected saving
   about 20 ms per 40K-RNA (hg19) events table, and less CPU on the server.
   Small: `idx_tx_gene_tx` on `(gene_name, tx_id)` is 7.8 MB, so this should be
   under that.

   ```sql
   CREATE INDEX CONCURRENTLY idx_tx_tx_id
       ON misspl_app.misspl_events_40k_hg19_tx (tx_id);
   ```

2. **`misspl_events_40k_hg19_events (gene_tx_id, ss_type, exon_no)`**, lower
   priority. It lets the events lookup go straight to the splice site instead
   of reading every event for the transcript (10,433 rows for TTN, 185 pages,
   about 3.5 ms warm, more cold). Expect roughly 0.5 GB, in line with the 359
   MB `idx_evnt_gene_tx_id`, which it would make redundant: once it is in use,
   `idx_evnt_gene_tx_id` could be dropped.

   ```sql
   CREATE INDEX CONCURRENTLY idx_evnt_tx_ss_exon
       ON misspl_app.misspl_events_40k_hg19_events (gene_tx_id, ss_type, exon_no);
   ```

No index is recommended for the 300K-RNA (hg38) queries. A covering index on
`tissue_missplicing_stats (misspl_stat_id, tissue_id)` would serve the
accessible tissues lookups, but on a 49 GB, 766M-row table it would be tens of
GB, and the app change above removes three quarters of those lookups for
nothing.

## Other observations

Not needed for the event queries, recorded in case they are useful. The usage
counts are `pg_stat_user_indexes` since its last reset (2022-07-13).

- `ref_tms_pk`, the 16 GB primary key index on
  `tissue_missplicing_stats (tissue_misspl_stat_id)`, has never been scanned.
- `idx_evnt_sstype` (350 MB, on a column with two values) has been scanned 25
  times; `idx_tx_gene_tx` and `idx_300k_hg38_tx_gene_tx` never.
- The planner expects 1 row from `missplicing_stats` for an exon and transcript
  and gets 55 to 192, because it treats `exon_id` and `transcript_id` as
  independent. The plans it picks are still the right ones, so nothing needs
  doing.
