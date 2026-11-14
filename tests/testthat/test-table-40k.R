# Characterisation tests for the events table on 40K-RNA (hg19). Each scenario
# stands alone: it opens the app, picks a splice site, clicks Generate Table
# and checks the table the user then sees. 40K-RNA has no tissue dropdown, so
# every scenario is for all tissues.
#
# The anchor is SMN1 NM_000344 (canonical) exon 6 Acceptor. It has exon
# skipping beyond the default 2 exons and cryptics beyond the default +/-600
# nt, so every "Show all" switch changes the table, and no two of its events
# share a sample count. Ties would make the row order non-deterministic (#67),
# so keep any new anchor tie-free. The events let in by raising the exon
# skipping or cryptic limits rank below the top 4, so the filter scenarios
# lower those limits instead.
#
# Snapshots are in _snaps/table-40k.md. They hold the title and every cell of
# every row; record changes with ./run_tests.sh --update-snapshots and review
# them in git diff.

# expect_snapshot() needs testthat's 3rd edition; the other test files run on
# the default 2nd edition.
testthat::local_edition(3)

describe("40K-RNA (hg19) events table", {
  it("with default settings shows the top 4 events within the default filters", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "6 (g.70240484)")

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
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "6 (g.70240484)")
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

describe("40K-RNA (hg19) events table filters", {
  it("Number of Events limits the table to that many events plus the annotated one", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "6 (g.70240484)")

      # When
      user_changes(session, "Number of Events", 2)
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  2 unannotated events in 40K-RNA (hg19) for NM_000344 (SMN1) Acceptor 6 (g.70240484) (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_events(session, data.frame(
        `Event` = c("annotated splicing", "exon skipping (annotated)", "cryptic acceptor"),
        `Cryptic Position` = c("", "", "+4"),
        `Total Samples` = c("22379 (100.0%)", "18047 (80.6%)", "9226 (41.2%)"),
        check.names = FALSE
      ))
    })
  })

  it("Maximum Number of Exons Skipped leaves out exon skipping across more exons", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "6 (g.70240484)")

      # When
      user_changes(session, "Maximum Number of Exons Skipped", 1)
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 40K-RNA (hg19) for NM_000344 (SMN1) Acceptor 6 (g.70240484) (max 1 exons skipped, cryptics within +/-600 nt)")
      expect_events(session, data.frame(
        `Event` = c("annotated splicing", "exon skipping (annotated)", "cryptic acceptor", "cryptic acceptor", "cryptic acceptor"),
        `Skipped Exons` = c("", "6", "", "", ""),
        `Cryptic Position` = c("", "", "+4", "-210", "-30"),
        check.names = FALSE
      ))
    })
  })

  it("Show Cryptics Within leaves out cryptics further from the splice site", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "6 (g.70240484)")

      # When
      user_changes(session, "Show Cryptics Within", 150)
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 40K-RNA (hg19) for NM_000344 (SMN1) Acceptor 6 (g.70240484) (max 2 exons skipped, cryptics within +/-150 nt)")
      expect_events(session, data.frame(
        `Event` = c("annotated splicing", "exon skipping (annotated)", "cryptic acceptor", "exon skipping", "cryptic acceptor"),
        `Skipped Exons` = c("", "6", "", "6-7", ""),
        `Cryptic Position` = c("", "", "+4", "", "-30"),
        check.names = FALSE
      ))
    })
  })
})

describe("40K-RNA (hg19) events table with no unannotated events", {
  it("a splice site whose only event within the filters is the annotated one shows just that row", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Gene", "HBB")
      user_selects(session, "Transcript", "ENST00000380315")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.5250481)")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_events(session, data.frame(
        `Event` = "annotated splicing",
        `Total Samples` = "351 (100.0%)",
        check.names = FALSE
      ))
    })
  })
})
