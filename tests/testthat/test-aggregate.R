make_sources <- function() {
  ot <- as_gene_table(
    data.frame(
      gene_symbol = c("TP53", "EGFR", "BRCA1"),
      source_score_raw = c(0.9, 0.7, 0.4),
      ensembl_id = c("E1", "E2", "E3"),
      evidence_type = "genetic"
    ),
    "opentargets"
  )
  dg <- as_gene_table(
    data.frame(
      gene_symbol = c("TP53", "EGFR"),
      source_score_raw = c(5, 3),
      evidence_type = "drug"
    ),
    "dgidb"
  )
  list(opentargets = ot, dgidb = dg)
}

test_that("aggregate_sources() pivots to one row per gene with score columns", {
  agg <- aggregate_sources(
    make_sources(),
    norm_methods = c(opentargets = "passthrough", dgidb = "rank")
  )

  expect_equal(nrow(agg), 3)
  expect_true(all(c("score_opentargets", "score_dgidb") %in% names(agg)))
  expect_equal(agg$n_sources[agg$gene_symbol == "TP53"], 2L)
  expect_equal(agg$n_sources[agg$gene_symbol == "BRCA1"], 1L)
})

test_that("genes absent from a source get NA, not zero", {
  agg <- aggregate_sources(make_sources())
  expect_true(is.na(agg$score_dgidb[agg$gene_symbol == "BRCA1"]))
})

test_that("passthrough keeps 0..1 scores; rank normalizes counts", {
  agg <- aggregate_sources(
    make_sources(),
    norm_methods = c(opentargets = "passthrough", dgidb = "rank")
  )
  expect_equal(agg$score_opentargets[agg$gene_symbol == "TP53"], 0.9)
  expect_equal(agg$score_dgidb[agg$gene_symbol == "TP53"], 1.0)
})

test_that("empty input yields the empty aggregated table", {
  expect_equal(nrow(aggregate_sources(list())), 0)
})

test_that("symbol_status() reports without repairing", {
  # Reporting only. This column exists BECAUSE blanket repair_id() is unsafe:
  # it turns "" into "AR" and ORF1AB into OR11A1 via a fuzzy path that
  # report_id() does not distinguish from the authoritative alias map.
  out <- symbol_status(c("TP53", "MLL", "ZZZNOTAGENE"))
  expect_equal(out[1], "valid")
  expect_equal(out[2], "alias of KMT2A")
  expect_equal(out[3], "unknown")
  expect_length(symbol_status(character()), 0)
})

test_that("symbol_status is added without changing any score", {
  ot <- as_gene_table(
    data.frame(gene_symbol = c("TP53", "MLL"), source_score_raw = c(0.9, 0.8)),
    "opentargets"
  )
  agg <- aggregate_sources(
    list(opentargets = ot),
    norm_methods = c(opentargets = "passthrough")
  )
  expect_true("symbol_status" %in% names(agg))
  # The alias is REPORTED, not merged: MLL stays MLL and keeps its own row.
  expect_setequal(agg$gene_symbol, c("TP53", "MLL"))
  expect_equal(agg$score_opentargets[agg$gene_symbol == "TP53"], 0.9)
  expect_equal(agg$score_opentargets[agg$gene_symbol == "MLL"], 0.8)
  expect_equal(agg$symbol_status[agg$gene_symbol == "MLL"], "alias of KMT2A")
})
