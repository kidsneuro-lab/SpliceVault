# Characterisation tests for the gene, transcript and exon dropdowns on
# 300K-RNA (hg38). Each scenario stands alone: it opens the app, does what a user would do
# and checks what the user then sees. Dropdown options are the exact text shown
# on screen, from the fixture database (tests/fixture).
#
# Most switch scenarios start from CNN2, its canonical transcript and the
# second exon in the dropdown, so a reset to the first exon is visible.
# Scenarios marked "current behaviour" pin behaviour that has an open issue;
# update them when it is fixed. Every fixture gene exists in both datasets and
# both transcript types, so falling back to the first gene is not covered yet
# (#64).

describe("300K-RNA (hg38), RefSeq transcripts", {
  it("the Gene/Transcript/Exon tab shows the first gene, its canonical transcript first and marked, and the first acceptor exon", {
    with_app({
      # Given / When
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("NM_001303501 (Canonical)", "NM_001303499"),
                      selected = "NM_001303501 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036066)",
                        "6 (g.1036415)",
                        "7 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })

  it("picking another gene selects its canonical transcript, and the exon goes back to the first exon", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Gene", "SMN1")

      # Then
      expect_dropdown(session, "Transcript",
                      options = c("NM_000344 (Canonical)", "NM_001297715"),
                      selected = "NM_000344 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.70938838)",
                        "3 (g.70941388)",
                        "4 (g.70942357)",
                        "5 (g.70942717)",
                        "6 (g.70944657)",
                        "7 (g.70946065)",
                        "8 (g.70951940)",
                        "9 (g.70952438)"
                      ),
                      selected = "2 (g.70938838)")
    })
  })

  it("picking another transcript lists its exons, and the exon goes back to the first exon", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Transcript", "NM_001303499")

      # Then
      expect_selected(session, "Transcript", "NM_001303499")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036129)",
                        "6 (g.1036415)",
                        "7 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })

  it("switching to Ensembl keeps the gene, selects the canonical Ensembl transcript, and the exon goes back to the first exon", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000263097 (Canonical)", "ENST00000348419"),
                      selected = "ENST00000263097 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036129)",
                        "6 (g.1036415)",
                        "7 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })

  # Exon 3 exists in both datasets, but they identify exons differently (see #60).
  it("switching to 40K-RNA keeps the gene and canonical transcript, and the exon goes back to the first (current behaviour, see #60)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("NM_001303501 (Canonical)", "NM_001303499"),
                      selected = "NM_001303501 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031069)",
                        "3 (g.1032390)",
                        "4 (g.1032557)",
                        "5 (g.1036065)",
                        "6 (g.1036414)",
                        "7 (g.1037623)"
                      ),
                      selected = "2 (g.1031069)")
    })
  })

  it("switching Acceptor to Donor keeps the selected exon when it has a donor site", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      expect_selected(session, "Exon", "2 (g.1031070)")

      # When
      user_selects(session, "Splice site", "Donor")

      # Then
      expect_dropdown(session, "Exon",
                      options = c(
                        "1 (g.1026725)",
                        "2 (g.1031193)",
                        "3 (g.1032459)",
                        "4 (g.1032697)",
                        "5 (g.1036247)",
                        "6 (g.1036563)"
                      ),
                      selected = "2 (g.1031193)")
    })
  })

  it("switching Donor to Acceptor goes back to the first exon when the selected exon has no acceptor site", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.1026725)")

      # When
      user_selects(session, "Splice site", "Acceptor")

      # Then
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036066)",
                        "6 (g.1036415)",
                        "7 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })
})

describe("300K-RNA (hg38), Ensembl transcripts", {
  it("the Gene/Transcript/Exon tab shows the first gene, its canonical transcript first and marked, and the first acceptor exon", {
    with_app({
      # Given / When
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000263097 (Canonical)", "ENST00000348419"),
                      selected = "ENST00000263097 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036129)",
                        "6 (g.1036415)",
                        "7 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })

  it("picking another gene selects its canonical transcript, and the exon goes back to the first exon", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Gene", "SMN1")

      # Then
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000380707 (Canonical)", "ENST00000351205"),
                      selected = "ENST00000380707 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.70938838)",
                        "3 (g.70941388)",
                        "4 (g.70942357)",
                        "5 (g.70942717)",
                        "6 (g.70944657)",
                        "7 (g.70946065)",
                        "8 (g.70951940)",
                        "9 (g.70952438)"
                      ),
                      selected = "2 (g.70938838)")
    })
  })

  it("picking another transcript lists its exons, and the exon goes back to the first exon", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Transcript", "ENST00000348419")

      # Then
      expect_selected(session, "Transcript", "ENST00000348419")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036415)",
                        "6 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })

  it("switching to RefSeq keeps the gene, selects the canonical RefSeq transcript, and the exon goes back to the first exon", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Transcript type", "RefSeq")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("NM_001303501 (Canonical)", "NM_001303499"),
                      selected = "NM_001303501 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031070)",
                        "3 (g.1032391)",
                        "4 (g.1032558)",
                        "5 (g.1036066)",
                        "6 (g.1036415)",
                        "7 (g.1037624)"
                      ),
                      selected = "2 (g.1031070)")
    })
  })
})

describe("300K-RNA (hg38) tissue dropdown", {
  it("is hidden after switching to 40K-RNA", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # When
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # Then
      expect_hidden(session, "Tissue")
    })
  })

  it("switching transcript type resets the tissue to All (current behaviour, see #62)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Tissue", "Blood - Whole*")

      # When
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_selected(session, "Tissue", "All")
    })
  })
})
