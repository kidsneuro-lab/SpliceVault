for (db in c("300K-RNA (hg38)", "40K-RNA (hg19)")) {
  test_that(paste("gene dropdown fills with the fixture genes for", db), {
    local_test_app()
    session <- recording_session()

    shiny::testServer(app_dir(), session = session, {
      do.call(session$setInputs, initial_inputs(db = db))

      genes <- dropdown(session, "geneInput")
      expect_equal(genes$value, fixture_genes)
      expect_equal(attr(genes, "selected"), fixture_genes[1])
    })
  })
}
