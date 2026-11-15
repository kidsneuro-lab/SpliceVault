# Query budgets per user interaction. Each round trip to the remote database
# costs far more than on the local fixture, so these counts are the guard
# against repeated queries. A budget covers everything the interaction sets
# off, including the dropdowns that refresh after it. When an optimisation
# lowers a count, lower the budget here to lock it in.
#
# Gene and tissue lists, and transcript and exon lists, are cached for the
# life of the app process (see helpers.R). Every with_app() loads the app
# afresh, so each scenario starts with nothing cached and its counts are the
# cold-cache ones: one query per dropdown level the interaction changes.

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

# Opens the app on the Gene/Transcript/Exon tab, on `dataset`.
opens_gene_tab <- function(session, dataset = "300K-RNA (hg38)") {
  user_opens_app(session)
  user_selects(session, "Tab", "Gene/Transcript/Exon")
  if (dataset != "300K-RNA (hg38)") user_selects(session, "Dataset", dataset)
}

describe("query budgets", {
  it("opening the app runs 4 queries (genes, transcripts, exons and tissues)", {
    with_app({
      expect_equal(count_queries(user_opens_app(session)), 4)
    })
  })

  # The app opens on 300K-RNA, so switching back to it later finds its lists
  # cached (see the round trip below).
  it("switching to 40K-RNA runs 3 queries (genes, transcripts, exons)", {
    with_app({
      opens_gene_tab(session)
      expect_equal(count_queries(user_selects(session, "Dataset", "40K-RNA (hg19)")), 3)
    })
  })

  for (dataset in c("300K-RNA (hg38)", "40K-RNA (hg19)")) {
    local({
      it(paste0(dataset, ": switching transcript type runs 3 queries (genes, transcripts, exons)"), {
        with_app({
          opens_gene_tab(session, dataset)
          expect_equal(count_queries(user_selects(session, "Transcript type", "Ensembl")), 3)
        })
      })

      it(paste0(dataset, ": picking a gene runs 2 queries (its transcripts, then the exons)"), {
        with_app({
          opens_gene_tab(session, dataset)
          expect_equal(count_queries(user_selects(session, "Gene", "HBB")), 2)
        })
      })

      it(paste0(dataset, ": picking a transcript runs 1 query (its exons)"), {
        with_app({
          opens_gene_tab(session, dataset)
          expect_equal(count_queries(user_selects(session, "Transcript", "NM_001303499")), 1)
        })
      })

      it(paste0(dataset, ": switching Acceptor to Donor runs 1 query (the exons)"), {
        with_app({
          opens_gene_tab(session, dataset)
          expect_equal(count_queries(user_selects(session, "Splice site", "Donor")), 1)
        })
      })
    })
  }

  it("switching dataset and back runs no queries on the way back", {
    with_app({
      opens_gene_tab(session)
      user_selects(session, "Dataset", "40K-RNA (hg19)")
      expect_equal(count_queries(user_selects(session, "Dataset", "300K-RNA (hg38)")), 0)
    })
  })

  it("a second user opening the app runs no queries", {
    with_two_users({
      as_user(user_a, user_opens_app(user_a))
      expect_equal(count_queries(as_user(user_b, user_opens_app(user_b))), 0)
    })
  })
})
