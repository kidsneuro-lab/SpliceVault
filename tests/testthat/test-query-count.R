# Query budgets per user interaction. Each round trip to the remote database
# costs far more than on the local fixture, so these counts are the guard
# against repeated queries. A budget covers everything the interaction sets
# off, including the dropdowns that refresh after it. When an optimisation
# lowers a count, lower the budget here to lock it in.

test_that("count_queries reports the queries run during an interaction", {
  with_app({
    expect_equal(count_queries(NULL), 0)
    expect_equal(count_queries(DBI::dbGetQuery(con, "SELECT 1")), 1)
    expect_equal(count_queries({
      DBI::dbGetQuery(con, "SELECT 1")
      DBI::dbExecute(con, "SELECT 1")
    }), 2)
  })
})

describe("query budgets", {
  it("300K-RNA (hg38): picking a gene runs 2 queries (its transcripts, then the exons)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")

      # When / Then
      expect_equal(count_queries(user_selects(session, "Gene", "HBB")), 2)
    })
  })

  it("40K-RNA (hg19): picking a gene runs 2 queries (its transcripts, then the exons)", {
    with_app({
      # Given
      user_opens_app(session)
      user_selects(session, "Tab", "Gene/Transcript/Exon")
      user_selects(session, "Dataset", "40K-RNA (hg19)")

      # When / Then
      expect_equal(count_queries(user_selects(session, "Gene", "HBB")), 2)
    })
  })
})
