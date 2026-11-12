# Characterisation tests for the input form in Gene/Transcript/Exon mode: the
# gene, transcript and exon dropdown chain, the tissue dropdown, the Generate
# Table button and Restore Settings. They pin what the user sees today, bugs
# included, so later refactors can be checked against them.

datasets <- c("300K-RNA (hg38)", "40K-RNA (hg19)")
tx_types <- c("RefSeq", "Ensembl")
other <- function(x, all) setdiff(all, x)

# Transcripts in the fixture, the same in both datasets.
transcripts <- list(
  CNN2 = list(RefSeq = c("NM_001303501", "NM_001303499"),
              Ensembl = c("ENST00000263097", "ENST00000348419")),
  SMN1 = list(RefSeq = c("NM_000344", "NM_001297715"),
              Ensembl = c("ENST00000380707", "ENST00000351205")),
  HBB = list(RefSeq = "NM_000518",
             Ensembl = c("ENST00000335295", "ENST00000380315"))
)
# Dropdown labels: canonical first and marked, then the rest.
tx_labels <- function(gene, tx_type) {
  ids <- transcripts[[gene]][[tx_type]]
  c(paste(ids[1], "(Canonical)"), ids[-1])
}

for (db in datasets) for (tx_type in tx_types) {
  case <- paste0(db, ", ", tx_type)

  test_that(paste("first load selects the first gene, its canonical transcript and first exon:", case), {
    with_app({
      open_app(session, db, tx_type)

      expect_equal(dropdown(session, "geneInput")$value, fixture_genes)
      expect_equal(input$geneInput, "CNN2")

      expect_equal(dropdown(session, "txInput")$label, tx_labels("CNN2", tx_type))
      expect_equal(selected_label(session, "txInput"), tx_labels("CNN2", tx_type)[1])

      exons <- dropdown(session, "exonInput")
      expect_match(exons$label, "^[0-9]+ \\(g\\.[0-9]+\\)$")
      expect_equal(exon_numbers(exons$label), 2:7)
      expect_equal(exon_numbers(selected_label(session, "exonInput")), 2)
    })
  })

  test_that(paste("picking a gene lists its transcripts, canonical first, and refreshes exons:", case), {
    with_app({
      open_app(session, db, tx_type)
      user_sets(session, geneInput = "SMN1")

      expect_equal(dropdown(session, "txInput")$label, tx_labels("SMN1", tx_type))
      expect_equal(selected_label(session, "txInput"), tx_labels("SMN1", tx_type)[1])
      expect_equal(exon_numbers(dropdown(session, "exonInput")$label), 2:9)
      expect_equal(exon_numbers(selected_label(session, "exonInput")), 2)
    })
  })

  test_that(paste("picking a transcript refreshes exons:", case), {
    with_app({
      open_app(session, db, tx_type)
      user_sets(session, geneInput = "SMN1")
      user_sets(session, exonInput = exon_value(session, 5))
      user_sets(session, txInput = tx_value(session, transcripts$SMN1[[tx_type]][2]))

      expect_equal(selected_label(session, "txInput"), transcripts$SMN1[[tx_type]][2])
      expect_equal(exon_numbers(dropdown(session, "exonInput")$label), 2:8)
      # 40K-RNA identifies exons by number, so exon 5 is still valid and kept.
      # 300K-RNA identifies them per transcript, so it falls back to the first.
      kept_exon <- if (db == "40K-RNA (hg19)") 5 else 2
      expect_equal(exon_numbers(selected_label(session, "exonInput")), kept_exon)
    })
  })

  test_that(paste("switching Acceptor/Donor lists that site's exons, keeping a still-valid exon:", case), {
    with_app({
      open_app(session, db, tx_type)
      # CNN2's non-canonical RefSeq transcript has 7 exons, its Ensembl one 6.
      non_canonical <- transcripts$CNN2[[tx_type]][2]
      last_exon <- if (tx_type == "RefSeq") 7 else 6
      user_sets(session, txInput = tx_value(session, non_canonical))
      user_sets(session, exonInput = exon_value(session, 3))

      user_sets(session, ssTypeInput = "Donor")
      expect_equal(selected_label(session, "txInput"), non_canonical)
      expect_equal(exon_numbers(dropdown(session, "exonInput")$label), 1:(last_exon - 1))
      expect_equal(exon_numbers(selected_label(session, "exonInput")), 3)

      # Exon 1 has no acceptor, so switching back falls back to the first exon.
      user_sets(session, exonInput = exon_value(session, 1))
      user_sets(session, ssTypeInput = "Acceptor")
      expect_equal(selected_label(session, "txInput"), non_canonical)
      expect_equal(exon_numbers(dropdown(session, "exonInput")$label), 2:last_exon)
      expect_equal(exon_numbers(selected_label(session, "exonInput")), 2)
    })
  })

  test_that(paste("switching transcript type keeps the gene and selects the new type's canonical transcript:", case), {
    new_type <- other(tx_type, tx_types)
    with_app({
      open_app(session, db, tx_type)
      user_sets(session, geneInput = "HBB")
      user_sets(session, txTypeInput = new_type)

      expect_equal(dropdown(session, "geneInput")$value, fixture_genes)
      expect_equal(input$geneInput, "HBB")
      expect_equal(dropdown(session, "txInput")$label, tx_labels("HBB", new_type))
      expect_equal(selected_label(session, "txInput"), tx_labels("HBB", new_type)[1])
      expect_equal(exon_numbers(selected_label(session, "exonInput")), 2)
    })
  })

  test_that(paste("switching dataset keeps the gene but resets transcript and exon:", case), {
    new_db <- other(db, datasets)
    with_app({
      open_app(session, db, tx_type)
      user_sets(session, geneInput = "SMN1")
      user_sets(session, txInput = tx_value(session, transcripts$SMN1[[tx_type]][2]))
      user_sets(session, exonInput = exon_value(session, 5))
      user_sets(session, dbInput = new_db)

      expect_equal(dropdown(session, "geneInput")$value, fixture_genes)
      expect_equal(input$geneInput, "SMN1")
      # The same transcript exists in both datasets, but the datasets use
      # different IDs for transcripts and exons, so neither selection survives.
      expect_equal(dropdown(session, "txInput")$label, tx_labels("SMN1", tx_type))
      expect_equal(selected_label(session, "txInput"), tx_labels("SMN1", tx_type)[1])
      expect_equal(exon_numbers(dropdown(session, "exonInput")$label), 2:9)
      expect_equal(exon_numbers(selected_label(session, "exonInput")), 2)
    })
  })
}

accessible_tissues <- c("Blood - Whole*", "Cells - Cultured fibroblasts*",
                        "Cells - EBV-transformed lymphocytes*", "Muscle - Skeletal*")

test_that("300K-RNA shows a tissue dropdown: All, then accessible tissues starred, then the rest", {
  with_app({
    open_app(session, "300K-RNA (hg38)")

    tissues <- tissue_options(session)
    expect_equal(tissues$label[1:5], c("All", accessible_tissues))
    expect_equal(tissues$value[1], "0")
    expect_equal(attr(tissues, "selected"), "0")
    expect_equal(input$tissuesInput, "0")
    rest <- tissues$label[-(1:5)]
    expect_length(rest, 51)
    expect_false(any(grepl("\\*$", rest)))
  })
})

test_that("300K-RNA resets the tissue to All when the transcript type changes", {
  with_app({
    open_app(session, "300K-RNA (hg38)")
    user_sets(session, tissuesInput = "5")
    user_sets(session, txTypeInput = "Ensembl")

    expect_equal(input$tissuesInput, "0")
  })
})

test_that("40K-RNA hides the tissue dropdown, and switching dataset toggles it", {
  with_app({
    open_app(session, "40K-RNA (hg19)")
    expect_null(tissue_options(session))

    user_sets(session, dbInput = "300K-RNA (hg38)")
    expect_equal(tissue_options(session)$label[1:5], c("All", accessible_tissues))

    user_sets(session, dbInput = "40K-RNA (hg19)")
    expect_null(tissue_options(session))
  })
})

for (db in datasets) {
  test_that(paste("Generate Table is enabled only while gene, transcript and exon are set:", db), {
    with_app({
      # Before the dropdowns fill, as the page first loads.
      do.call(session$setInputs, initial_inputs(db = db))
      expect_equal(js_state(session, "confirm"), "disable")

      settle(session)
      expect_equal(js_state(session, "confirm"), "enable")

      user_sets(session, exonInput = "")
      expect_equal(js_state(session, "confirm"), "disable")
      user_sets(session, exonInput = exon_value(session, 3))
      expect_equal(js_state(session, "confirm"), "enable")

      user_sets(session, txInput = "")
      expect_equal(js_state(session, "confirm"), "disable")
      user_sets(session, txInput = tx_value(session, transcripts$CNN2$RefSeq[1]))
      expect_equal(js_state(session, "confirm"), "enable")

      user_sets(session, geneInput = "")
      expect_equal(js_state(session, "confirm"), "disable")
      user_sets(session, geneInput = "HBB")
      expect_equal(js_state(session, "confirm"), "enable")
    })
  })

  test_that(paste("Restore Settings resets every setting and the dataset:", db), {
    with_app({
      open_app(session, db, "Ensembl")
      user_sets(session, ssTypeInput = "Donor", geneInput = "SMN1")
      changed <- list(eventsNoInput = 10, allevents = TRUE, esInput = 5,
                      allskips = TRUE, cssInput = 300, allcryptics = TRUE)
      if (db == "300K-RNA (hg38)") changed$tissuesInput <- "5"
      do.call(user_sets, c(list(session), changed))

      user_sets(session, restore = 1)

      for (id in names(default_settings)) {
        expect_equal(input[[id]], default_settings[[id]], label = id)
      }
      expect_equal(input$dbInput, "300K-RNA (hg38)")
      expect_equal(input$tissuesInput, "0")
      expect_equal(attr(tissue_options(session), "selected"), "0")
      # Transcript type, splice site and gene are left as they were.
      expect_equal(input$txTypeInput, "Ensembl")
      expect_equal(input$ssTypeInput, "Donor")
      expect_equal(input$geneInput, "SMN1")
      expect_equal(selected_label(session, "txInput"), tx_labels("SMN1", "Ensembl")[1])
    })
  })
}
