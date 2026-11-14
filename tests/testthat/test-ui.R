# Characterisation tests for the parts of the page that do not depend on the
# dataset: what the page opens with, the sidebar settings, Restore Settings and
# the Generate Table button. They run on 300K-RNA (hg38) with RefSeq, the page
# defaults. Each scenario stands alone: it opens the app, does what a user
# would do and checks what the user then sees.

describe("Opening the page", {
  it("shows the Variant tab", {
    with_app({
      # Given / When
      user_opens_app(session)

      # Then
      expect_selected(session, "Tab", "Variant")
    })
  })

  it("starts with the default settings and All tissues", {
    with_app({
      # Given / When
      user_opens_app(session)

      # Then
      expect_setting(session, "Number of Events", 4)
      expect_setting(session, "Show all Events", FALSE)
      expect_setting(session, "Maximum Number of Exons Skipped", 2)
      expect_setting(session, "Show all Exon Skipping", FALSE)
      expect_setting(session, "Show Cryptics Within", 600)
      expect_setting(session, "Show all Cryptics", FALSE)
      expect_selected(session, "Tissue", "All")
    })
  })

  it("lists All, then the clinically accessible tissues starred, then the rest", {
    with_app({
      # Given / When
      user_opens_app(session)

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

  it("fills the gene, transcript and exon dropdowns behind the Variant tab, and selecting the Gene/Transcript/Exon tab keeps them", {
    with_app({
      # Given
      user_opens_app(session)

      # When
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # Then
      expect_selected(session, "Dataset", "300K-RNA (hg38)")
      expect_selected(session, "Transcript type", "RefSeq")
      expect_selected(session, "Splice site", "Acceptor")
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

describe("Sidebar settings", {
  it("ticking Show all Events greys out Number of Events, and unticking it frees the slider again", {
    with_app({
      # Given
      user_opens_app(session)
      expect_enabled(session, "Number of Events", TRUE)

      # When
      user_changes(session, "Show all Events", TRUE)

      # Then
      expect_enabled(session, "Number of Events", FALSE)

      # When
      user_changes(session, "Show all Events", FALSE)

      # Then
      expect_enabled(session, "Number of Events", TRUE)
    })
  })

  it("ticking Show all Exon Skipping greys out Maximum Number of Exons Skipped, and unticking it frees the slider again", {
    with_app({
      # Given
      user_opens_app(session)
      expect_enabled(session, "Maximum Number of Exons Skipped", TRUE)

      # When
      user_changes(session, "Show all Exon Skipping", TRUE)

      # Then
      expect_enabled(session, "Maximum Number of Exons Skipped", FALSE)

      # When
      user_changes(session, "Show all Exon Skipping", FALSE)

      # Then
      expect_enabled(session, "Maximum Number of Exons Skipped", TRUE)
    })
  })

  it("ticking Show all Cryptics greys out Show Cryptics Within, and unticking it frees the slider again", {
    with_app({
      # Given
      user_opens_app(session)
      expect_enabled(session, "Show Cryptics Within", TRUE)

      # When
      user_changes(session, "Show all Cryptics", TRUE)

      # Then
      expect_enabled(session, "Show Cryptics Within", FALSE)

      # When
      user_changes(session, "Show all Cryptics", FALSE)

      # Then
      expect_enabled(session, "Show Cryptics Within", TRUE)
    })
  })
})

describe("Restore Settings", {
  it("resets every setting and the tissue to their defaults", {
    with_app({
      # Given
      user_opens_app(session)
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
      expect_selected(session, "Tissue", "All")
    })
  })

  # Whether Restore Settings should touch these is an open question (#63).
  it("leaves transcript type, splice site, gene and transcript as they were (current behaviour, see #63)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Transcript type", "Ensembl")
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

describe("Generate Table button", {
  it("is disabled while the page loads, before the dropdowns are filled", {
    with_app({
      # Given / When
      app_starts_loading(session)

      # Then
      expect_enabled(session, "Generate Table", FALSE)
    })
  })

  it("is enabled once gene, transcript and exon are filled in", {
    with_app({
      # Given / When
      user_opens_app(session)

      # Then
      expect_enabled(session, "Generate Table", TRUE)
    })
  })

  it("is disabled when the exon is cleared, and enabled again when one is picked", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # When
      user_clears(session, "Exon")

      # Then
      expect_enabled(session, "Generate Table", FALSE)

      # When
      user_selects(session, "Exon", "3 (g.1032391)")

      # Then
      expect_enabled(session, "Generate Table", TRUE)
    })
  })

  it("is disabled when the transcript is cleared, and enabled again when one is picked", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # When
      user_clears(session, "Transcript")

      # Then
      expect_enabled(session, "Generate Table", FALSE)

      # When
      user_selects(session, "Transcript", "NM_001303501 (Canonical)")

      # Then
      expect_enabled(session, "Generate Table", TRUE)
    })
  })

  it("is disabled when the gene is cleared, and enabled again when one is picked", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # When
      user_clears(session, "Gene")

      # Then
      expect_enabled(session, "Generate Table", FALSE)

      # When
      user_selects(session, "Gene", "HBB")

      # Then
      expect_enabled(session, "Generate Table", TRUE)
    })
  })
})
