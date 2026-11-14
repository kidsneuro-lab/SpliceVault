# Characterisation tests for the events table on 300K-RNA (hg38). Each
# scenario stands alone: it opens the app, picks a splice site, clicks
# Generate Table and checks the table the user then sees.
#
# The anchor is CNN2 NM_001303501 (canonical) exon 2 Donor, with Whole Blood
# for one tissue. It has exon skipping beyond the default 2 exons and cryptics
# beyond the default +/-600 nt, so every "Show all" switch changes the table,
# and no two of its events share a sample count, in all tissues or in Whole
# Blood. Ties would make the row order non-deterministic (#67), so keep any new
# anchor tie-free.
#
# Snapshots are in _snaps/table-300k.md. They hold the title, the accessible
# tissues legend and every cell of every row; record changes with
# ./run_tests.sh --update-snapshots and review them in git diff.

# expect_snapshot() needs testthat's 3rd edition; the other test files run on
# the default 2nd edition.
testthat::local_edition(3)

describe("300K-RNA (hg38) events table, all tissues", {
  it("with default settings shows the top 4 events within the default filters", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_snapshot(print_events_table(session))
    })
  })

  it("with every \"Show all\" box ticked shows every event", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")
      user_changes(session, "Show all Events", TRUE)
      user_changes(session, "Show all Exon Skipping", TRUE)
      user_changes(session, "Show all Cryptics", TRUE)

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_snapshot(print_events_table(session))
    })
  })
})

describe("300K-RNA (hg38) events table, one tissue", {
  it("with default settings shows the top 4 events in that tissue within the default filters", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")
      user_selects(session, "Tissue", "Blood - Whole*")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_snapshot(print_events_table(session))
    })
  })

  it("with every \"Show all\" box ticked shows every event in that tissue", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")
      user_selects(session, "Tissue", "Blood - Whole*")
      user_changes(session, "Show all Events", TRUE)
      user_changes(session, "Show all Exon Skipping", TRUE)
      user_changes(session, "Show all Cryptics", TRUE)

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_snapshot(print_events_table(session))
    })
  })
})

describe("300K-RNA (hg38) events table filters", {
  it("Number of Events limits the table to that many events plus the annotated one", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")

      # When
      user_changes(session, "Number of Events", 2)
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  2 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_events(session, data.frame(
        `Event` = c("annotated splicing", "exon skipping", "exon skipping"),
        `Skipped Exons` = c("", "2", "2-3"),
        `Total Samples` = c("232401 (100.0%)", "2193 (0.9%)", "80 (0.0%)"),
        check.names = FALSE
      ))
    })
  })

  it("Maximum Number of Exons Skipped lets in exon skipping across more exons", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")

      # When
      user_changes(session, "Maximum Number of Exons Skipped", 4)
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (max 4 exons skipped, cryptics within +/-600 nt)")
      expect_events(session, data.frame(
        `Event` = c("annotated splicing", "exon skipping", "exon skipping", "exon skipping", "cryptic donor"),
        `Skipped Exons` = c("", "2", "2-5", "2-3", ""),
        `Cryptic Position` = c("", "", "", "", "+5"),
        check.names = FALSE
      ))
    })
  })

  it("Show Cryptics Within lets in cryptics further from the splice site", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "2 (g.1031193)")

      # When
      user_changes(session, "Show Cryptics Within", 1000)
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_001303501 (CNN2) Donor 2 (g.1031193) (max 2 exons skipped, cryptics within +/-1000 nt)")
      expect_events(session, data.frame(
        `Event` = c("annotated splicing", "exon skipping", "exon skipping", "cryptic donor", "cryptic donor"),
        `Skipped Exons` = c("", "2", "2-3", "", ""),
        `Cryptic Position` = c("", "", "", "+855", "+5"),
        check.names = FALSE
      ))
    })
  })
})

describe("300K-RNA (hg38) events table with no unannotated events", {
  it("in all tissues, a splice site whose only event within the filters is the annotated one shows just that row", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Gene", "HBB")
      user_selects(session, "Transcript", "ENST00000380315")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.5229251)")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_events(session, data.frame(
        `Event` = "annotated splicing",
        `Total Samples` = "1515 (100.0%)",
        check.names = FALSE
      ))
    })
  })

  it("in a tissue with no events at the splice site, the table is empty", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Gene", "HBB")
      user_selects(session, "Transcript", "ENST00000380315")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.5229251)")
      user_selects(session, "Tissue", "Cells - Cultured fibroblasts*")

      # When
      # The splice junction step warns on an empty result ("no non-missing
      # arguments to min"); the user sees nothing of it.
      suppressWarnings(user_clicks(session, "Generate Table"))

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for ENST00000380315  [Cells - Cultured fibroblasts*] (HBB) Donor 1 (g.5229251) (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_equal(nrow(events_table(session)), 0)
    })
  })
})
