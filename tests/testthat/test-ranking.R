make_agg <- function() {
  tibble::tibble(
    gene_symbol = c("TP53", "EGFR", "BRCA1"),
    ensembl_id = c("E1", "E2", "E3"),
    entrez_id = NA_character_,
    n_sources = c(2L, 2L, 1L),
    sources = c("dgidb, opentargets", "dgidb, opentargets", "opentargets"),
    evidence = "x",
    score_opentargets = c(0.9, 0.7, 0.4),
    score_dgidb = c(1.0, 0.5, NA)
  )
}

test_that("combined_score = weighted evidence x coverage factor", {
  agg <- make_agg()
  r <- rank_genes(
    agg,
    weights = c(opentargets = 1, dgidb = 1),
    coverage_bonus = 0.5,
    n_total = 2
  )

  # TP53: weights normalize to 0.5/0.5; evidence = .5*.9 + .5*1 = .95
  # coverage factor (2 sources of 2) = 1 + 0.5*(2-1)/(2-1) = 1.5
  expect_equal(r$combined_score[r$gene_symbol == "TP53"], 0.95 * 1.5)
  expect_equal(r$rank[1], 1L)
  expect_equal(r$gene_symbol[1], "TP53")
})

test_that("coverage_bonus = 0 disables the breadth reward", {
  r <- rank_genes(make_agg(), coverage_bonus = 0, n_total = 2)
  expect_equal(r$combined_score[r$gene_symbol == "TP53"], 0.5 * 0.9 + 0.5 * 1.0)
})

test_that("absent-source genes are not zero-imputed (single-source survives)", {
  # BRCA1 present only in opentargets (0.4); with full weight it should still
  # score on its own evidence, not be dragged to 0 by the missing dgidb score.
  r <- rank_genes(
    make_agg(),
    weights = c(opentargets = 1, dgidb = 0),
    coverage_bonus = 0,
    n_total = 2
  )
  expect_equal(r$combined_score[r$gene_symbol == "BRCA1"], 0.4)
})

test_that("weights bias the ranking", {
  r <- rank_genes(
    make_agg(),
    weights = c(opentargets = 0, dgidb = 1),
    coverage_bonus = 0,
    n_total = 2
  )
  # With only dgidb weighted, TP53 (1.0) > EGFR (0.5) > BRCA1 (NA->0)
  expect_equal(r$gene_symbol, c("TP53", "EGFR", "BRCA1"))
})

test_that("empty aggregate returns zero rows", {
  expect_equal(nrow(rank_genes(aggregate_sources(list()))), 0)
})
