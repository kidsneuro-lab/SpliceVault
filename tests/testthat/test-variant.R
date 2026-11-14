# Characterisation tests for Variant mode. Each scenario stands alone: it
# opens the app on the Variant tab (300K-RNA, the default), enters an HGVS
# variant, clicks Generate Table and checks what the user then sees.
#
# Variants are looked up with the Ensembl REST VEP endpoint. Its responses are
# recorded in tests/testthat/ensembl and replayed, so these tests run offline
# and a request with no recording fails. Re-record them with
# ./run_tests.sh --record-ensembl variant (see tests/README.md). The variants
# are made up for these tests.
#
# A resolved variant shows the transcript, gene, splice site and exon in the
# table title; the first event shows that the table was filled for it. HBB is
# on the negative strand and HBA1 on the positive strand. An exonic variant
# resolves to the nearest splice site of its exon; + resolves to the donor of
# the exon before the intron and - to the acceptor of the exon after it.
# An input that cannot be resolved shows an error message as the title.

describe("Variant mode on the negative strand (HBB)", {
  it("an exonic variant at the start of exon 3 resolves to the exon 3 acceptor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5(HBB):c.316C>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000518 (HBB) Acceptor 3 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an intronic variant before exon 3 (-) resolves to the exon 3 acceptor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5(HBB):c.316-1G>A")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000518 (HBB) Acceptor 3 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an exonic variant at the end of exon 2 resolves to the exon 2 donor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5(HBB):c.315G>A")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000518 (HBB) Donor 2 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an intronic variant after exon 2 (+) resolves to the exon 2 donor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5(HBB):c.315+1G>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000518 (HBB) Donor 2 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an Ensembl transcript variant after exon 2 (+) resolves to the exon 2 donor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "ENST00000335295.4:c.315+1G>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for ENST00000335295 (HBB) Donor 2 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })
})

describe("Variant mode on the positive strand (HBA1)", {
  it("an exonic variant at the end of exon 1 resolves to the exon 1 donor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000558.5(HBA1):c.95G>A")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000558 (HBA1) Donor 1 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an intronic variant after exon 1 (+) resolves to the exon 1 donor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000558.5(HBA1):c.95+1G>A")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000558 (HBA1) Donor 1 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an intronic variant before exon 3 (-) resolves to the exon 3 acceptor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000558.5(HBA1):c.301-1G>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000558 (HBA1) Acceptor 3 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })

  it("an exonic variant at the start of exon 3 resolves to the exon 3 acceptor", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000558.5(HBA1):c.301C>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Showing top  4 unannotated events in 300K-RNA (hg38) for NM_000558 (HBA1) Acceptor 3 (max 2 exons skipped, cryptics within +/-600 nt)")
      expect_first_event(session, "annotated splicing")
    })
  })
})

describe("Variant mode with input that cannot be resolved", {
  it("a RefSeq transcript with no version shows that no transcript was found", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518:c.316C>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "No transcript accession matching 'NM_000518:c.316C>T' identified. Please enter a valid ENSEMBL or RefSeq transcript (e.g. NM_004006.3).")
    })
  })

  it("a truncated RefSeq transcript with no version shows that no transcript was found", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_0005:c.316C>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "No transcript accession matching 'NM_0005:c.316C>T' identified. Please enter a valid ENSEMBL or RefSeq transcript (e.g. NM_004006.3).")
    })
  })

  it("text with no transcript shows that no transcript was found", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "DUMMY_VALUE")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "No transcript accession matching 'DUMMY_VALUE' identified. Please enter a valid ENSEMBL or RefSeq transcript (e.g. NM_004006.3).")
    })
  })

  it("a wrong reference allele shows the correct one", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5:c.316A>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Incorrect reference allele provided: (A). Correct reference allele is: (C). Ensure you have selected the correct transcript. You entered: NM_000518.5")
    })
  })

  it("a transcript Ensembl does not know shows that no transcript was found", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_9999999.1:c.316C>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "No transcript accession matching NM_9999999.1 identified. Please enter a valid ENSEMBL or RefSeq transcript.(e.g. NM_004006.3)")
    })
  })

  it("a position beyond the end of the transcript shows that it cannot be mapped", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5:c.9999C>T")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "Unable to map the cDNA coordinates for 'NM_000518' Please double check your input.")
    })
  })

  it("a variant Ensembl cannot interpret shows the generic error", {
    with_app({
      # Given
      user_opens_app(session)
      user_enters_variant(session, "NM_000518.5:c.316")

      # When
      user_clicks(session, "Generate Table")

      # Then
      expect_table_title(session, "An unknown error occurred. Please double check your input: 'NM_000518:c.316'.")
    })
  })
})
