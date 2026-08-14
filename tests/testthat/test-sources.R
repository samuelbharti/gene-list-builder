# Source adapters are tested by injecting a fake graphql_fn that returns the
# same parsed-list shape the real client would, so no network is touched.

test_that("resolve_disease() parses Open Targets search hits", {
  fake <- function(query, variables = list(), ...) {
    list(
      search = list(
        hits = list(
          list(
            id = "MONDO_1",
            name = "lung cancer",
            score = 99,
            description = "d1"
          ),
          list(
            id = "EFO_2",
            name = "lung carcinoma",
            score = 50,
            description = "d2"
          )
        )
      )
    )
  }
  cand <- resolve_disease("lung cancer", graphql_fn = fake)
  expect_equal(nrow(cand), 2)
  expect_equal(cand$id[1], "MONDO_1")
  expect_equal(cand$name[2], "lung carcinoma")
})

test_that("resolve_disease() handles a pasted ontology id", {
  fake <- function(query, variables = list(), ...) {
    list(
      disease = list(
        id = "EFO_0000305",
        name = "breast carcinoma",
        description = "d"
      )
    )
  }
  cand <- resolve_disease("EFO:0000305", graphql_fn = fake)
  expect_equal(nrow(cand), 1)
  expect_equal(cand$id, "EFO_0000305")
  expect_equal(cand$name, "breast carcinoma")
})

test_that("resolve_disease() preserves case for mixed-case ids (Orphanet)", {
  seen <- NULL
  fake <- function(query, variables = list(), ...) {
    seen <<- variables$efoId
    list(disease = list(id = variables$efoId, name = "some rare disease"))
  }
  cand <- resolve_disease("Orphanet:158673", graphql_fn = fake)
  # ":" -> "_" but case preserved (Open Targets uses "Orphanet_...", not upper).
  expect_equal(seen, "Orphanet_158673")
  expect_equal(cand$id, "Orphanet_158673")
})

test_that("resolve_disease() returns empty on blank or no match", {
  expect_equal(nrow(resolve_disease("", graphql_fn = function(...) NULL)), 0)
  empty <- function(...) list(search = list(hits = list()))
  expect_equal(nrow(resolve_disease("zzz", graphql_fn = empty)), 0)
})

test_that("fetch_opentargets() maps associated targets to the schema", {
  fake <- function(query, variables = list(), ...) {
    list(
      disease = list(
        id = "MONDO_1",
        name = "x",
        associatedTargets = list(
          count = 2,
          rows = list(
            list(
              score = 0.9,
              target = list(id = "ENSG1", approvedSymbol = "TP53")
            ),
            list(
              score = 0.7,
              target = list(id = "ENSG2", approvedSymbol = "EGFR")
            )
          )
        )
      )
    )
  }
  gt <- fetch_opentargets(list(id = "MONDO_1"), graphql_fn = fake)
  expect_true(validate_gene_table(gt))
  expect_equal(gt$gene_symbol, c("TP53", "EGFR"))
  expect_equal(gt$source_score_raw, c(0.9, 0.7))
  expect_true(all(grepl("ENSG", gt$ensembl_id)))
})

test_that("fetch_opentargets() degrades to empty on missing disease/id", {
  expect_equal(nrow(fetch_opentargets(list(id = ""))), 0)
  null_fn <- function(...) NULL
  expect_equal(nrow(fetch_opentargets(list(id = "X"), graphql_fn = null_fn)), 0)
})

test_that("fetch_dgidb() scores genes by interaction count", {
  # bioclients returns one row per INPUT symbol: NA interaction_count for a
  # gene DGIdb has never heard of, 0 for a known gene with no interactions.
  # The adapter must drop both, as the previous implementation did.
  fake <- function(symbols, ...) {
    biohttp::status_ok(
      tibble::tibble(
        symbol = c("EGFR", "BRCA1", "ZZZNOTAGENE"),
        concept_id = c("hgnc:3236", "hgnc:1100", NA_character_),
        interaction_count = c(2L, 0L, NA_integer_),
        source_url = c(
          "https://dgidb.org/genes/hgnc:3236",
          "https://dgidb.org/genes/hgnc:1100",
          NA_character_
        )
      ),
      source = "DGIdb"
    )
  }
  gt <- fetch_dgidb(
    gene_symbols = c("EGFR", "BRCA1", "ZZZNOTAGENE"),
    client_fn = fake
  )
  expect_equal(gt$gene_symbol, "EGFR")
  expect_equal(gt$source_score_raw, 2)
  expect_equal(gt$n_evidence, 2L)
})

test_that("fetch_dgidb() chunks its input rather than sending one huge query", {
  seen <- list()
  fake <- function(symbols, ...) {
    seen[[length(seen) + 1]] <<- symbols
    biohttp::status_ok(
      tibble::tibble(
        symbol = symbols,
        concept_id = paste0("hgnc:", seq_along(symbols)),
        interaction_count = rep(1L, length(symbols)),
        source_url = rep("https://dgidb.org/", length(symbols))
      ),
      source = "DGIdb"
    )
  }
  gt <- fetch_dgidb(
    gene_symbols = paste0("G", 1:250),
    chunk_size = 100,
    client_fn = fake
  )
  expect_equal(lengths(seen), c(100L, 100L, 50L))
  expect_equal(nrow(gt), 250L)
})

test_that("fetch_dgidb() degrades to an empty table when the client fails", {
  failing <- function(symbols, ...) biohttp::status_error(source = "DGIdb")
  gt <- fetch_dgidb(gene_symbols = c("EGFR"), client_fn = failing)
  expect_equal(nrow(gt), 0)
  expect_true(validate_gene_table(gt))
})

test_that("fetch_dgidb() returns empty when no seed genes are provided", {
  expect_equal(nrow(fetch_dgidb(gene_symbols = character())), 0)
  expect_equal(nrow(fetch_dgidb(gene_symbols = NULL)), 0)
})
