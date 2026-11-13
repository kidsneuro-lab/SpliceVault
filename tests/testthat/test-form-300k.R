# Characterisation tests for the 300K-RNA (hg38) input form in Gene/Transcript/Exon mode.
# Each scenario stands alone: it opens the app, does what a user would do and
# checks what the user then sees. Dropdown options are the exact text shown on
# screen, from the fixture database (tests/fixture). Scenarios marked "current
# behaviour" pin behaviour that has an open issue; update them when it is fixed.
#
# Every fixture gene exists in both datasets and both transcript types, so
# falling back to the first gene after a switch is not covered yet (#64).

describe("300K-RNA (hg38), RefSeq transcripts: gene, transcript and exon dropdowns", {
  it("on opening, selects the first gene, its canonical transcript and its first acceptor exon", {
    with_app({
      # Given / When
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

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

  it("picking a gene lists its transcripts, canonical first and marked, and its acceptor exons", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

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

  # The exon falls back even though exon 5 exists in the new transcript, unlike
  # 40K-RNA, which keeps the exon number.
  it("picking another transcript lists its exons and resets the exon to the first (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "5 (g.70942717)")

      # When
      user_selects(session, "Transcript", "NM_001297715")

      # Then
      expect_selected(session, "Transcript", "NM_001297715")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.70938838)",
                        "3 (g.70941388)",
                        "4 (g.70942357)",
                        "5 (g.70942717)",
                        "6 (g.70944657)",
                        "7 (g.70946065)",
                        "8 (g.70952438)"
                      ),
                      selected = "2 (g.70938838)")
    })
  })

  it("switching to Donor lists donor exons and keeps the selected exon when it has a donor site", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_selects(session, "Transcript", "NM_001303499")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Splice site", "Donor")

      # Then
      expect_selected(session, "Transcript", "NM_001303499")
      expect_dropdown(session, "Exon",
                      options = c(
                        "1 (g.1026725)",
                        "2 (g.1031193)",
                        "3 (g.1032459)",
                        "4 (g.1032664)",
                        "5 (g.1036247)",
                        "6 (g.1036563)"
                      ),
                      selected = "3 (g.1032459)")
    })
  })

  it("switching to Acceptor falls back to the first exon when the selected exon has no acceptor site", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_selects(session, "Transcript", "NM_001303499")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.1026725)")

      # When
      user_selects(session, "Splice site", "Acceptor")

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

  it("switching to Ensembl keeps the gene and selects its canonical Ensembl transcript and first exon", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_selects(session, "Gene", "HBB")

      # When
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "HBB")
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000335295 (Canonical)", "ENST00000380315"),
                      selected = "ENST00000335295 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c("2 (g.5226800)", "3 (g.5225727)"),
                      selected = "2 (g.5226800)")
    })
  })

  # NM_001297715 and exon 5 exist in both datasets, but the two datasets
  # identify transcripts and exons differently, so neither selection survives.
  it("switching to 40K-RNA keeps the gene but resets transcript and exon (current behaviour, see #60)", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Transcript", "NM_001297715")
      user_selects(session, "Exon", "5 (g.70942717)")

      # When
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "SMN1")
      expect_dropdown(session, "Transcript",
                      options = c("NM_000344 (Canonical)", "NM_001297715"),
                      selected = "NM_000344 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.70234665)",
                        "3 (g.70237215)",
                        "4 (g.70238184)",
                        "5 (g.70238544)",
                        "6 (g.70240484)",
                        "7 (g.70241892)",
                        "8 (g.70247767)",
                        "9 (g.70248265)"
                      ),
                      selected = "2 (g.70234665)")
    })
  })
})

describe("300K-RNA (hg38), Ensembl transcripts: gene, transcript and exon dropdowns", {
  it("on opening, selects the first gene, its canonical transcript and its first acceptor exon", {
    with_app({
      # Given / When
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")

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

  it("picking a gene lists its transcripts, canonical first and marked, and its acceptor exons", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")

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

  # The exon falls back even though exon 5 exists in the new transcript, unlike
  # 40K-RNA, which keeps the exon number.
  it("picking another transcript lists its exons and resets the exon to the first (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Exon", "5 (g.70942717)")

      # When
      user_selects(session, "Transcript", "ENST00000351205")

      # Then
      expect_selected(session, "Transcript", "ENST00000351205")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.70938838)",
                        "3 (g.70941388)",
                        "4 (g.70942357)",
                        "5 (g.70942717)",
                        "6 (g.70944657)",
                        "7 (g.70946065)",
                        "8 (g.70951940)"
                      ),
                      selected = "2 (g.70938838)")
    })
  })

  it("switching to Donor lists donor exons and keeps the selected exon when it has a donor site", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")
      user_selects(session, "Transcript", "ENST00000348419")
      user_selects(session, "Exon", "3 (g.1032391)")

      # When
      user_selects(session, "Splice site", "Donor")

      # Then
      expect_selected(session, "Transcript", "ENST00000348419")
      expect_dropdown(session, "Exon",
                      options = c(
                        "1 (g.1026725)",
                        "2 (g.1031193)",
                        "3 (g.1032459)",
                        "4 (g.1032697)",
                        "5 (g.1036563)"
                      ),
                      selected = "3 (g.1032459)")
    })
  })

  it("switching to Acceptor falls back to the first exon when the selected exon has no acceptor site", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")
      user_selects(session, "Transcript", "ENST00000348419")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.1026725)")

      # When
      user_selects(session, "Splice site", "Acceptor")

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

  it("switching to RefSeq keeps the gene and selects its canonical RefSeq transcript and first exon", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")
      user_selects(session, "Gene", "HBB")

      # When
      user_selects(session, "Transcript type", "RefSeq")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "HBB")
      expect_dropdown(session, "Transcript",
                      options = "NM_000518 (Canonical)",
                      selected = "NM_000518 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c("2 (g.5226800)", "3 (g.5225727)"),
                      selected = "2 (g.5226800)")
    })
  })

  # ENST00000351205 and exon 5 exist in both datasets, but the two datasets
  # identify transcripts and exons differently, so neither selection survives.
  it("switching to 40K-RNA keeps the gene but resets transcript and exon (current behaviour, see #60)", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Transcript", "ENST00000351205")
      user_selects(session, "Exon", "5 (g.70942717)")

      # When
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "SMN1")
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000380707 (Canonical)", "ENST00000351205"),
                      selected = "ENST00000380707 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.70234665)",
                        "3 (g.70237215)",
                        "4 (g.70238184)",
                        "5 (g.70238544)",
                        "6 (g.70240484)",
                        "7 (g.70241892)",
                        "8 (g.70247767)",
                        "9 (g.70248265)"
                      ),
                      selected = "2 (g.70234665)")
    })
  })
})

describe("300K-RNA (hg38): tissue dropdown (transcript type does not affect this)", {
  it("lists All, then the clinically accessible tissues starred, then the rest, with All selected", {
    with_app({
      # Given / When
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # Then
      expect_dropdown(session, "Tissue",
                      options = c(
                        "All",
                        "Blood - Whole*",
                        "Cells - Cultured fibroblasts*",
                        "Cells - EBV-transformed lymphocytes*",
                        "Muscle - Skeletal*",
                        "Adipose - Subcutaneous",
                        "Adipose - Visceral (Omentum)",
                        "Adrenal Gland",
                        "Artery - Aorta",
                        "Artery - Coronary",
                        "Artery - Tibial",
                        "Bladder",
                        "Brain - Amygdala",
                        "Brain - Anterior cingulate cortex (BA24)",
                        "Brain - Caudate (basal ganglia)",
                        "Brain - Cerebellar Hemisphere",
                        "Brain - Cerebellum",
                        "Brain - Cortex",
                        "Brain - Frontal Cortex (BA9)",
                        "Brain - Hippocampus",
                        "Brain - Hypothalamus",
                        "Brain - Nucleus accumbens (basal ganglia)",
                        "Brain - Putamen (basal ganglia)",
                        "Brain - Spinal cord (cervical c-1)",
                        "Brain - Substantia nigra",
                        "Breast - Mammary Tissue",
                        "Cells - Leukemia cell line (CML)",
                        "Cervix - Ectocervix",
                        "Cervix - Endocervix",
                        "Colon - Sigmoid",
                        "Colon - Transverse",
                        "Esophagus - Gastroesophageal Junction",
                        "Esophagus - Mucosa",
                        "Esophagus - Muscularis",
                        "Fallopian Tube",
                        "Heart - Atrial Appendage",
                        "Heart - Left Ventricle",
                        "Kidney - Cortex",
                        "Kidney - Medulla",
                        "Liver",
                        "Lung",
                        "Minor Salivary Gland",
                        "Nerve - Tibial",
                        "Ovary",
                        "Pancreas",
                        "Pituitary",
                        "Prostate",
                        "Skin - Not Sun Exposed (Suprapubic)",
                        "Skin - Sun Exposed (Lower leg)",
                        "Small Intestine - Terminal Ileum",
                        "Spleen",
                        "Stomach",
                        "Testis",
                        "Thyroid",
                        "Uterus",
                        "Vagina"
                      ),
                      selected = "All")
    })
  })

  it("is hidden after switching to 40K-RNA", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # When
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # Then
      expect_hidden(session, "Tissue")
    })
  })

  it("switching transcript type resets the tissue to All (current behaviour, see #62)", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_selects(session, "Tissue", "Blood - Whole*")

      # When
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_selected(session, "Tissue", "All")
    })
  })
})

describe("300K-RNA (hg38): Generate Table button (transcript type does not affect this)", {
  it("is disabled while the page loads, before the dropdowns are filled", {
    with_app({
      # Given / When
      app_starts_loading(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # Then
      expect_button(session, "Generate Table", enabled = FALSE)
    })
  })

  it("is enabled once gene, transcript and exon are filled in", {
    with_app({
      # Given / When
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # Then
      expect_button(session, "Generate Table", enabled = TRUE)
    })
  })

  it("is disabled when the exon is cleared, and enabled again when one is picked", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # When
      user_clears(session, "Exon")

      # Then
      expect_button(session, "Generate Table", enabled = FALSE)

      # When
      user_selects(session, "Exon", "3 (g.1032391)")

      # Then
      expect_button(session, "Generate Table", enabled = TRUE)
    })
  })

  it("is disabled when the transcript is cleared, and enabled again when one is picked", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # When
      user_clears(session, "Transcript")

      # Then
      expect_button(session, "Generate Table", enabled = FALSE)

      # When
      user_selects(session, "Transcript", "NM_001303501 (Canonical)")

      # Then
      expect_button(session, "Generate Table", enabled = TRUE)
    })
  })

  it("is disabled when the gene is cleared, and enabled again when one is picked", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")

      # When
      user_clears(session, "Gene")

      # Then
      expect_button(session, "Generate Table", enabled = FALSE)

      # When
      user_selects(session, "Gene", "HBB")

      # Then
      expect_button(session, "Generate Table", enabled = TRUE)
    })
  })
})

describe("300K-RNA (hg38): Restore Settings (transcript type does not affect this)", {
  it("resets every setting and the tissue to their defaults", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "RefSeq")
      user_changes(session, "Number of Events", 10)
      user_changes(session, "Show all Events", TRUE)
      user_changes(session, "Maximum Number of Exons Skipped", 5)
      user_changes(session, "Show all Exon Skipping", TRUE)
      user_changes(session, "Show Cryptics Within", 300)
      user_changes(session, "Show all Cryptics", TRUE)
      user_selects(session, "Tissue", "Blood - Whole*")

      # When
      user_clicks(session, "Restore Settings")

      # Then
      expect_setting(session, "Number of Events", 4)
      expect_setting(session, "Show all Events", FALSE)
      expect_setting(session, "Maximum Number of Exons Skipped", 2)
      expect_setting(session, "Show all Exon Skipping", FALSE)
      expect_setting(session, "Show Cryptics Within", 600)
      expect_setting(session, "Show all Cryptics", FALSE)
      expect_selected(session, "Dataset", "300K-RNA (hg38)")
      expect_selected(session, "Tissue", "All")
    })
  })

  # Whether Restore Settings should touch these is an open question (#63).
  it("leaves transcript type, splice site, gene and transcript as they were (current behaviour, see #63)", {
    with_app({
      # Given
      user_opens_app(session, dataset = "300K-RNA (hg38)", transcripts = "Ensembl")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Gene", "SMN1")
      user_selects(session, "Transcript", "ENST00000351205")

      # When
      user_clicks(session, "Restore Settings")

      # Then
      expect_selected(session, "Transcript type", "Ensembl")
      expect_selected(session, "Splice site", "Donor")
      expect_selected(session, "Gene", "SMN1")
      expect_selected(session, "Transcript", "ENST00000351205")
    })
  })
})
