# Unit tests for the functions that build the events table's title, columns
# and rows (helpers.R). They need no database or session, so they run in
# seconds: ./run_tests.sh table-format. The characterisation tests in
# test-table-*.R and test-variant.R check the same output end to end.

h <- app_helpers()

title <- function(...) {
  defaults <- list(db = "300K-RNA (hg38)", transcript = "NM_001303501 (Canonical)",
                   gene = "CNN2", ss_type = "Donor", exon = "2 (g.1031193)",
                   events_no = 4, max_skipped = 2, max_cryptic = 600)
  do.call(h$events_table_title, utils::modifyList(defaults, list(...)))
}

describe("events_table_title()", {
  it("describes the top N events with both filters on, without the canonical marker", {
    expect_equal(title(),
                 "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (max 2 exons skipped, cryptics within +/-600 nt)")
  })

  it("says \"all\" when every event is shown", {
    expect_equal(title(events_no = NULL),
                 "Showing all unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (max 2 exons skipped, cryptics within +/-600 nt)")
  })

  it("names only the exon skipping filter when every cryptic is shown", {
    expect_equal(title(max_cryptic = NULL),
                 "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (max 2 exons skipped)")
  })

  it("names only the cryptic filter, without \"nt\", when all exon skipping is shown", {
    expect_equal(title(max_skipped = NULL),
                 "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (cryptics within +/-600)")
  })

  it("names no filter when both are off", {
    expect_equal(title(max_skipped = NULL, max_cryptic = NULL),
                 "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193)")
  })

  it("names the tissue in brackets after the transcript", {
    expect_equal(title(tissue = "Blood - Whole*"),
                 "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501  [Blood - Whole*] (CNN2) Donor 2 (g.1031193) (max 2 exons skipped, cryptics within +/-600 nt)")
  })
})

describe("events_table_columns()", {
  it("gives 300K-RNA (hg38) for all tissues its SRA and accessible tissue columns on hg38", {
    columns <- h$events_table_columns("300K-RNA (hg38)", tissue_selected = FALSE)
    expect_length(columns$colnames, 13)
    expect_true(all(c("SRA?", "Accessible Tissues (GTEx)") %in% columns$colnames))
    expect_equal(columns$genome, "hg38")
  })

  it("drops the SRA and accessible tissue columns for one 300K-RNA (hg38) tissue", {
    columns <- h$events_table_columns("300K-RNA (hg38)", tissue_selected = TRUE)
    expect_length(columns$colnames, 9)
    expect_false(any(c("SRA?", "Samples (SRA)", "Total Samples", "Accessible Tissues (GTEx)") %in% columns$colnames))
    expect_equal(columns$genome, "hg38")
  })

  it("gives 40K-RNA (hg19) its Intropolis columns on hg19", {
    columns <- h$events_table_columns("40K-RNA (hg19)", tissue_selected = FALSE)
    expect_length(columns$colnames, 12)
    expect_true(all(c("Intropolis?", "Samples (Intropolis)") %in% columns$colnames))
    expect_equal(columns$genome, "hg19")
  })

  it("only targets columns that exist", {
    for (spec in list(h$events_table_columns("300K-RNA (hg38)", FALSE),
                      h$events_table_columns("300K-RNA (hg38)", TRUE),
                      h$events_table_columns("40K-RNA (hg19)", FALSE))) {
      targets <- unlist(lapply(spec$columnDefs, `[[`, "targets"))
      expect_true(all(targets >= 0 & targets < length(spec$colnames)))
    }
  })
})

events <- function(...) {
  data.frame(splicing_event_class = c("normal splicing", "cryptic donor", "exon skipping"),
             cryptic_distance = c(NA, 25, -7),
             sample_count = c(200, 50, 1),
             chr = "chr1",
             donor_pos = c(100, 125, 93),
             acceptor_pos = c(300, 300, 500),
             stringsAsFactors = FALSE)
}

describe("format_events()", {
  it("shows each event's splice junction, IGV link, sample share and signed cryptic distance", {
    shown <- as.data.frame(h$format_events(events(), "hg38"))
    expect_equal(names(shown), c("splicing_event_class", "cryptic_distance", "sample_count", "sj", "igv"))
    expect_equal(shown$splicing_event_class, c("annotated splicing", "cryptic donor", "exon skipping"))
    expect_equal(shown$cryptic_distance, c(NA, "+25", "-7"))
    expect_equal(shown$sample_count, c("200 (100.0%)", "50 (25.0%)", "1 (0.5%)"))
    expect_equal(shown$sj, c("chr1:100-300", "chr1:125-300", "chr1:93-500"))
    expect_equal(shown$igv[1], '<a href="http://localhost:60151/goto?locus=chr1:100-300&genome=hg38">link</a>')
  })

  it("orders the splice junction by position when the donor is after the acceptor", {
    rows <- events()
    rows$donor_pos[2] <- 400
    expect_equal(as.data.frame(h$format_events(rows, "hg19"))$sj[2], "chr1:300-400")
  })

  it("links to the genome build it is given", {
    expect_match(as.data.frame(h$format_events(events(), "hg19"))$igv[1], "genome=hg19", fixed = TRUE)
  })

  it("keeps any other columns as they are", {
    rows <- cbind(events(), in_gtex = c("Yes", "No", "Yes"))
    expect_equal(as.data.frame(h$format_events(rows, "hg38"))$in_gtex, c("Yes", "No", "Yes"))
  })

  it("shows no rows for an exon with no events", {
    # rowwise() min() on zero rows warns, as it always has; vectorising the
    # formatter (#52) can drop that.
    shown <- suppressWarnings(as.data.frame(h$format_events(events()[0, ], "hg38")))
    expect_equal(nrow(shown), 0)
    expect_equal(names(shown), c("splicing_event_class", "cryptic_distance", "sample_count", "sj", "igv"))
  })
})
