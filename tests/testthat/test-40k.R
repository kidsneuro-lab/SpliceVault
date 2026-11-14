# Characterisation tests for the gene, transcript and exon dropdowns on
# 40K-RNA (hg19). Each scenario stands alone: it opens the app, does what a user would do
# and checks what the user then sees. Dropdown options are the exact text shown
# on screen, from the fixture database (tests/fixture).
#
# Most switch scenarios start from CNN2, its canonical transcript and the
# second exon in the dropdown, so a reset to the first exon is visible.
# Scenarios marked "current behaviour" pin behaviour that has an open issue;
# update them when it is fixed. Every fixture gene exists in both datasets and
# both transcript types, so falling back to the first gene is not covered yet
# (#64).

describe("40K-RNA (hg19), RefSeq transcripts", {
  it("the Gene/Transcript/Exon tab shows the first gene, its canonical transcript first and marked, and the first acceptor exon", {
    with_app({
      # Given / When
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
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

  # 40K-RNA identifies exons by number, so exon 3 stays selected (see #61).
  it("picking another gene selects its canonical transcript, and the exon stays on exon 3 (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Gene", "SMN1")

      # Then
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
                      selected = "3 (g.70237215)")
    })
  })

  # 40K-RNA identifies exons by number, so exon 3 stays selected (see #61).
  it("picking another transcript lists its exons, and the exon stays on exon 3 (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Transcript", "NM_001303499")

      # Then
      expect_selected(session, "Transcript", "NM_001303499")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031069)",
                        "3 (g.1032390)",
                        "4 (g.1032557)",
                        "5 (g.1036128)",
                        "6 (g.1036414)",
                        "7 (g.1037623)"
                      ),
                      selected = "3 (g.1032390)")
    })
  })

  # 40K-RNA identifies exons by number, so exon 3 stays selected (see #61).
  it("switching to Ensembl keeps the gene, selects the canonical Ensembl transcript, and the exon stays on exon 3 (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000263097 (Canonical)", "ENST00000348419"),
                      selected = "ENST00000263097 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031069)",
                        "3 (g.1032390)",
                        "4 (g.1032557)",
                        "5 (g.1036128)",
                        "6 (g.1036414)",
                        "7 (g.1037623)"
                      ),
                      selected = "3 (g.1032390)")
    })
  })

  # Exon 3 exists in both datasets, but they identify exons differently (see #60).
  it("switching to 300K-RNA keeps the gene and canonical transcript, and the exon goes back to the first (current behaviour, see #60)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Dataset", "300K-RNA (hg38)")

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

  it("switching Acceptor to Donor keeps the selected exon when it has a donor site", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      expect_selected(session, "Exon", "2 (g.1031069)")

      # When
      user_selects(session, "Splice site", "Donor")

      # Then
      expect_dropdown(session, "Exon",
                      options = c(
                        "1 (g.1026724)",
                        "2 (g.1031192)",
                        "3 (g.1032458)",
                        "4 (g.1032696)",
                        "5 (g.1036246)",
                        "6 (g.1036562)"
                      ),
                      selected = "2 (g.1031192)")
    })
  })

  it("switching Donor to Acceptor goes back to the first exon when the selected exon has no acceptor site", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Splice site", "Donor")
      user_selects(session, "Exon", "1 (g.1026724)")

      # When
      user_selects(session, "Splice site", "Acceptor")

      # Then
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
})

describe("40K-RNA (hg19), Ensembl transcripts", {
  it("the Gene/Transcript/Exon tab shows the first gene, its canonical transcript first and marked, and the first acceptor exon", {
    with_app({
      # Given / When
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Transcript type", "Ensembl")

      # Then
      expect_dropdown(session, "Gene", options = c("CNN2", "HBA1", "HBB", "INS", "SMN1"), selected = "CNN2")
      expect_dropdown(session, "Transcript",
                      options = c("ENST00000263097 (Canonical)", "ENST00000348419"),
                      selected = "ENST00000263097 (Canonical)")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031069)",
                        "3 (g.1032390)",
                        "4 (g.1032557)",
                        "5 (g.1036128)",
                        "6 (g.1036414)",
                        "7 (g.1037623)"
                      ),
                      selected = "2 (g.1031069)")
    })
  })

  # 40K-RNA identifies exons by number, so exon 3 stays selected (see #61).
  it("picking another gene selects its canonical transcript, and the exon stays on exon 3 (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Gene", "SMN1")

      # Then
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
                      selected = "3 (g.70237215)")
    })
  })

  # 40K-RNA identifies exons by number, so exon 3 stays selected (see #61).
  it("picking another transcript lists its exons, and the exon stays on exon 3 (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Transcript", "ENST00000348419")

      # Then
      expect_selected(session, "Transcript", "ENST00000348419")
      expect_dropdown(session, "Exon",
                      options = c(
                        "2 (g.1031069)",
                        "3 (g.1032390)",
                        "4 (g.1032557)",
                        "5 (g.1036414)",
                        "6 (g.1037623)"
                      ),
                      selected = "3 (g.1032390)")
    })
  })

  # 40K-RNA identifies exons by number, so exon 3 stays selected (see #61).
  it("switching to RefSeq keeps the gene, selects the canonical RefSeq transcript, and the exon stays on exon 3 (current behaviour, see #61)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      user_selects(session, "Transcript type", "Ensembl")
      user_selects(session, "Exon", "3 (g.1032390)")

      # When
      user_selects(session, "Transcript type", "RefSeq")

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
                      selected = "3 (g.1032390)")
    })
  })
})

describe("40K-RNA (hg19) tissue dropdown and settings", {
  it("hides the tissue dropdown", {
    with_app({
      # Given / When
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # Then
      expect_hidden(session, "Tissue")
    })
  })

  it("switching to 300K-RNA shows the tissue dropdown with All selected", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # When
      user_selects(session, "Dataset", "300K-RNA (hg38)")

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

  it("Restore Settings switches back to 300K-RNA with All tissues", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # When
      user_clicks(session, "Restore Settings")

      # Then
      expect_selected(session, "Dataset", "300K-RNA (hg38)")
      expect_selected(session, "Tissue", "All")
    })
  })
})
