test_that("empty_gene_table() has exactly the canonical columns", {
  tbl <- empty_gene_table()
  expect_true(validate_gene_table(tbl))
  expect_equal(nrow(tbl), 0)
  expect_setequal(names(tbl), names(GENE_TABLE_COLS))
})

test_that("as_gene_table() normalizes symbols and drops blanks", {
  df <- data.frame(
    gene_symbol = c("tp53", " egfr ", NA, ""),
    source_score_raw = c(0.9, 0.5, 0.1, 0.2),
    ensembl_id = c("ENSG1", "ENSG2", "ENSG3", "ENSG4")
  )
  out <- as_gene_table(df, "opentargets")

  expect_true(validate_gene_table(out))
  expect_equal(out$gene_symbol, c("TP53", "EGFR"))
  expect_true(all(out$source_id == "opentargets"))
  expect_true(all(nzchar(out$retrieved_at)))
})

test_that("as_gene_table() returns the empty schema for NULL/empty input", {
  expect_equal(nrow(as_gene_table(NULL, "x")), 0)
  expect_equal(nrow(as_gene_table(data.frame(), "x")), 0)
})

test_that("validate_gene_table() rejects wrong shapes", {
  expect_false(validate_gene_table(data.frame(a = 1)))
  expect_false(validate_gene_table(list()))
})
