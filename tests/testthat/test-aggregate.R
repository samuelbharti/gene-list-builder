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

# --- Corroborated alias repair (GLB_REPAIR_SYMBOLS) --------------------------

test_that("repair is OFF by default, so scores are untouched", {
  withr::local_envvar(GLB_REPAIR_SYMBOLS = "")
  ot <- as_gene_table(
    data.frame(gene_symbol = c("KMT2A"), source_score_raw = 0.9),
    "opentargets"
  )
  pa <- as_gene_table(
    data.frame(gene_symbol = c("MLL"), source_score_raw = 1.0),
    "panelapp"
  )
  agg <- aggregate_sources(list(opentargets = ot, panelapp = pa))
  expect_setequal(agg$gene_symbol, c("KMT2A", "MLL")) # still split
  expect_equal(agg$n_sources, c(1L, 1L))
})

test_that("an alias merges when the modern symbol IS in the run", {
  withr::local_envvar(GLB_REPAIR_SYMBOLS = "1")
  ot <- as_gene_table(
    data.frame(gene_symbol = c("KMT2A"), source_score_raw = 0.9),
    "opentargets"
  )
  pa <- as_gene_table(
    data.frame(gene_symbol = c("MLL"), source_score_raw = 1.0),
    "panelapp"
  )
  agg <- aggregate_sources(list(opentargets = ot, panelapp = pa))
  # One gene, two sources: the split evidence is reunited and n_sources is now
  # correct, which is what the coverage bonus depends on.
  expect_equal(agg$gene_symbol, "KMT2A")
  expect_equal(agg$n_sources, 2L)
  expect_true(all(c("score_opentargets", "score_panelapp") %in% names(agg)))
})

test_that("an alias does NOT merge when the modern symbol is absent", {
  withr::local_envvar(GLB_REPAIR_SYMBOLS = "1")
  # Nothing in this run reports KMT2A, so MLL stays put rather than being
  # rewritten to a gene no source actually mentioned.
  pa <- as_gene_table(
    data.frame(gene_symbol = c("MLL", "TP53"), source_score_raw = c(1.0, 0.5)),
    "panelapp"
  )
  agg <- aggregate_sources(list(panelapp = pa))
  expect_setequal(agg$gene_symbol, c("MLL", "TP53"))
})

test_that("a fuzzy suggestion cannot invent a gene", {
  withr::local_envvar(GLB_REPAIR_SYMBOLS = "1")
  # repair_id("ORF1AB") suggests OR11A1 via a fuzzy match, which is wrong.
  # The corroboration gate blocks it because no source reported OR11A1.
  expect_equal(
    biobouncer::repair_id("ORF1AB", "hgnc", how = "cache"),
    "OR11A1"
  )
  pa <- as_gene_table(
    data.frame(gene_symbol = c("ORF1AB", "TP53"), source_score_raw = c(1, 1)),
    "panelapp"
  )
  agg <- aggregate_sources(list(panelapp = pa))
  expect_true("ORF1AB" %in% agg$gene_symbol)
  expect_false("OR11A1" %in% agg$gene_symbol)
})

test_that("case-only suggestions do not resplit the key", {
  withr::local_envvar(GLB_REPAIR_SYMBOLS = "1")
  # repair_id("C9ORF72") returns "C9orf72": correct per HGNC but a case change
  # that would undo as_gene_table()'s toupper() and split the group key the
  # other way. target != toupper(input) filters it out.
  ot <- as_gene_table(
    data.frame(gene_symbol = "C9ORF72", source_score_raw = 0.9),
    "opentargets"
  )
  agg <- aggregate_sources(list(opentargets = ot))
  expect_equal(agg$gene_symbol, "C9ORF72")
})

test_that("mature microRNA names are labelled, not reported as unknown", {
  # The text-mined sources contribute miRNA names, which are not HGNC gene
  # symbols. Reporting them as "unknown" reads like a data error rather than a
  # different kind of entity.
  out <- symbol_status(c("HSA-MIR-21-5P", "hsa-let-7a-5p", "TP53", "ZZZNOPE"))
  expect_equal(out[1], "microRNA (not HGNC)")
  expect_equal(out[2], "microRNA (not HGNC)")
  expect_equal(out[3], "valid")
  expect_equal(out[4], "unknown")
})
