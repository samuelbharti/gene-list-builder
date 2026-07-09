ranked_fixture <- function() {
  tibble::tibble(
    gene_symbol = c("TP53", "EGFR", "KRAS", "BRAF"),
    n_sources = c(2L, 2L, 1L, 2L),
    sources = "opentargets, dgidb",
    combined_score = c(1.4, 1.3, 0.8, 1.2),
    rank = 1:4
  )
}

test_that("validate_curation() drops hallucinations and clamps confidence", {
  df <- tibble::tibble(
    gene_symbol = c("TP53", "FAKE1", "egfr"),
    include = c(TRUE, TRUE, NA),
    confidence = c(1.5, 0.9, 0.3),
    rationale = c("a", NA, "c")
  )
  v <- validate_curation(df, candidate_symbols = ranked_fixture()$gene_symbol)

  expect_false("FAKE1" %in% v$gene_symbol) # hallucinated symbol dropped
  expect_equal(v$confidence[v$gene_symbol == "TP53"], 1) # clamped to 1
  expect_false(v$include[v$gene_symbol == "EGFR"]) # NA include -> FALSE
})

test_that("fallback_curation() picks the top-N by rank", {
  fb <- fallback_curation(ranked_fixture(), top_n = 2)
  expect_equal(nrow(fb), 2)
  expect_true(all(fb$include))
  expect_true(all(is.na(fb$confidence)))
})

test_that("curate_gene_list() uses an injected chat and validates output", {
  stub <- function(system_prompt) {
    list(chat_structured = function(user, type) {
      list(
        selections = data.frame(
          gene_symbol = c("EGFR", "TP53", "NOTREAL"),
          include = c(TRUE, TRUE, TRUE),
          confidence = c(0.9, 0.95, 0.8),
          rationale = c("driver", "tsg", "hallucinated"),
          stringsAsFactors = FALSE
        ),
        overall_notes = "picked drivers"
      )
    })
  }
  res <- curate_gene_list(
    ranked_fixture(),
    "lung cancer",
    top_n = 10,
    chat_factory = stub
  )

  expect_true(isTRUE(attr(res, "ai_used")))
  expect_false("NOTREAL" %in% res$gene_symbol)
  expect_setequal(res$gene_symbol, c("EGFR", "TP53"))
})

test_that("curate_gene_list() falls back when the chat errors", {
  boom <- function(system_prompt) {
    list(chat_structured = function(user, type) stop("api down"))
  }
  res <- curate_gene_list(
    ranked_fixture(),
    "lung cancer",
    top_n = 2,
    chat_factory = boom
  )

  expect_false(isTRUE(attr(res, "ai_used")))
  expect_equal(nrow(res), 2)
  expect_match(attr(res, "error"), "api down")
})

test_that("curate_gene_list() with no key and no factory falls back", {
  withr::local_envvar(GEMINI_API_KEY = "")
  res <- curate_gene_list(ranked_fixture(), "lung cancer", top_n = 3)
  expect_false(isTRUE(attr(res, "ai_used")))
  expect_equal(nrow(res), 3)
})
