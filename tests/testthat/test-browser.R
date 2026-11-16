# Browser tests: the app in headless Chrome, checked through what the page
# shows. They cover what the server-function tests cannot see: the table DT
# draws, the Generate Table button's real state and the export files DT builds
# in the browser. Variant mode is covered by test-variant.R instead, since the
# app's own R process cannot use the recorded Ensembl responses.
#
# The anchors are the splice sites of test-table-300k.R and test-table-40k.R:
# CNN2 NM_001303501 exon 2 Donor (4 rows, 10 with every "Show all" box ticked)
# and SMN1 NM_000344 exon 6 Acceptor (5 rows, 15 with every box ticked, which
# is more than one table page).

describe("Generate Table in the browser", {
  it("is greyed out while the dropdowns fill, then clickable", {
    # Given: each query takes long enough to see the page before it is ready
    app <- local_browser_app(wait = FALSE, latency_ms = 500)

    # Then
    expect_button(app, "Generate Table", "disabled")
    app$wait_for_idle()
    expect_button(app, "Generate Table", "enabled")
  })

  it("is greyed out once the gene is cleared, and clickable again once one is picked", {
    # Given
    app <- browser_opens_app()
    browser_selects(app, "Tab", "Gene/Transcript/Exon")
    expect_false(button_disabled(app, "Generate Table"))

    # When
    browser_clears(app, "Gene")

    # Then
    expect_button(app, "Generate Table", "disabled")

    # When
    browser_selects(app, "Gene", "SMN1")

    # Then
    expect_button(app, "Generate Table", "enabled")
  })
})

describe("300K-RNA (hg38) events table in the browser", {
  it("with default settings draws the top 4 events, and every export works", {
    # Given
    app <- browser_opens_app()
    browser_selects(app, "Tab", "Gene/Transcript/Exon")
    browser_selects(app, "Splice site", "Donor")
    browser_selects(app, "Exon", "2 (g.1031193)")

    # When
    browser_generates_table(app)

    # Then
    shown <- shown_table(app)
    expect_equal(shown$rows, 4)
    expect_equal(shown$rows_on_page, 4)
    expect_true("Splice Junction" %in% shown$headers)
    expect_exports_work(app)
  })

  it("with every \"Show all\" box ticked draws every event, and every export works", {
    # Given
    app <- browser_opens_app()
    browser_selects(app, "Tab", "Gene/Transcript/Exon")
    browser_selects(app, "Splice site", "Donor")
    browser_selects(app, "Exon", "2 (g.1031193)")
    browser_changes(app, "Show all Events", TRUE)
    browser_changes(app, "Show all Exon Skipping", TRUE)
    browser_changes(app, "Show all Cryptics", TRUE)

    # When
    browser_generates_table(app)

    # Then
    shown <- shown_table(app)
    expect_equal(shown$rows, 10)
    expect_exports_work(app)
  })
})

describe("40K-RNA (hg19) events table in the browser", {
  it("with default settings draws the top 4 events, and every export works", {
    # Given
    app <- browser_opens_app()
    browser_selects(app, "Tab", "Gene/Transcript/Exon")
    browser_selects(app, "Dataset", "40K-RNA (hg19)")
    browser_selects(app, "Gene", "SMN1")
    browser_selects(app, "Exon", "6 (g.70240484)")

    # When
    browser_generates_table(app)

    # Then
    shown <- shown_table(app)
    expect_equal(shown$rows, 5)
    expect_equal(shown$rows_on_page, 5)
    expect_true("Splice Junction" %in% shown$headers)
    expect_exports_work(app)
  })

  it("with every \"Show all\" box ticked draws every event over two pages, and every export has them all", {
    # Given
    app <- browser_opens_app()
    browser_selects(app, "Tab", "Gene/Transcript/Exon")
    browser_selects(app, "Dataset", "40K-RNA (hg19)")
    browser_selects(app, "Gene", "SMN1")
    browser_selects(app, "Exon", "6 (g.70240484)")
    browser_changes(app, "Show all Events", TRUE)
    browser_changes(app, "Show all Exon Skipping", TRUE)
    browser_changes(app, "Show all Cryptics", TRUE)

    # When
    browser_generates_table(app)

    # Then
    shown <- shown_table(app)
    expect_equal(shown$rows, 15)
    expect_equal(shown$rows_on_page, 11)
    expect_exports_work(app)
  })
})

describe("Header in the browser", {
  it("has an Understanding SpliceVault button with a film icon that opens the video guide in a new tab, its label fitting on the button", {
    # Given / When
    app <- local_browser_app()

    # Then
    button <- header_button(app, "Understanding SpliceVault")
    expect_false(is.null(button))
    expect_match(button$icon, "fa-film", fixed = TRUE)
    expect_equal(button$onclick, "window.open('https://www.youtube.com/watch?v=xfksZH3jPwM', '_blank')")
    expect_true(button$fits)
  })

  it("no longer has the SpliceVault Version 2.0 button", {
    # Given / When
    app <- local_browser_app()

    # Then
    labels <- vapply(header_buttons(app), `[[`, "", "label")
    expect_setequal(labels, c("Understanding SpliceVault", "Report an issue"))
  })
})
