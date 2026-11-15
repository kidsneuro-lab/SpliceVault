# The app's connection pool (open_db_pool() in db.R): a connection the server
# dropped is replaced before a query uses it, and the app closes its
# connections when it stops.

for (db in c("300K-RNA (hg38)", "40K-RNA (hg19)")) {
  describe(paste("after the server drops the app's connection,", db), {
    it("the next interaction still fills the dropdowns", {
      admin <- local_admin_connection()
      with_app({
        # Given
        user_opens_app(session)
        user_selects(session, "Tab", "Gene/Transcript/Exon")
        user_selects(session, "Dataset", db)
        server_drops_app_connections(admin)

        # When
        expect_output(user_selects(session, "Gene", "SMN1"),
                      "Failed to activate and/or validate existing object")

        # Then
        expect_dropdown(session, "Transcript",
                        options = c("NM_000344 (Canonical)", "NM_001297715"),
                        selected = "NM_000344 (Canonical)")
        expect_gt(nrow(dropdown_options(session, "Exon")), 0)
      })
    })
  })
}

test_that("stopping the app closes its database connections", {
  admin <- local_admin_connection()
  with_app({
    user_opens_app(session)
    expect_gt(length(app_backends(admin)), 0)

    # What shiny::runApp() does as the app stops.
    shiny:::.globals$onStopCallbacks$invoke()

    expect_false(DBI::dbIsValid(con))
    wait_for(length(app_backends(admin)) == 0, "the app's backends to end")
  })
})
