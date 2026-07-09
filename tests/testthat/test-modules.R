# Reactive-logic tests for the Shiny modules via shiny::testServer().
# Network and AI dependencies are injected as stubs.

test_that("run_pipeline fires only on Run and aggregates source results", {
  stub_run <- function(disease, source_ids, force = FALSE, on_progress = NULL) {
    list(
      results = list(
        opentargets = as_gene_table(
          data.frame(
            gene_symbol = c("TP53", "EGFR"),
            source_score_raw = c(0.9, 0.5)
          ),
          "opentargets"
        )
      ),
      status = tibble::tibble(
        source_id = "opentargets",
        label = "Open Targets",
        ok = TRUE,
        n_genes = 2L,
        latency_ms = 1L,
        message = "ok"
      )
    )
  }
  disease <- shiny::reactiveVal(list(id = "MONDO_1", name = "demo disease"))
  sources <- shiny::reactiveVal("opentargets")

  shiny::testServer(
    run_pipeline_server,
    args = list(
      disease_reactive = disease,
      sources_reactive = sources,
      run_sources_fn = stub_run
    ),
    {
      session$setInputs(run = 1, force = FALSE)
      out <- session$returned()
      expect_false(is.null(out))
      expect_equal(out$n_sources, 1)
      expect_equal(nrow(out$aggregated), 2)
      expect_true("gene_symbol" %in% names(out$aggregated))

      # Editing sources without clicking Run does not change the snapshot.
      sources("dgidb")
      expect_equal(session$returned()$disease$id, "MONDO_1")
    }
  )
})

test_that("disease_search returns the selected candidate row", {
  fake_resolve <- function(term, ...) {
    tibble::tibble(
      id = c("MONDO_1", "MONDO_2"),
      name = c("a", "b"),
      score = c(2, 1),
      description = NA_character_
    )
  }
  shiny::testServer(
    disease_search_server,
    args = list(resolve_fn = fake_resolve),
    {
      session$setInputs(term = "cancer")
      session$setInputs(resolve = 1)
      session$setInputs(choice = "MONDO_2")
      sel <- session$returned()
      expect_equal(sel$id, "MONDO_2")
      expect_equal(sel$name, "b")
    }
  )
})

test_that("curation uses the injected curator and returns its table", {
  ranked <- shiny::reactive(tibble::tibble(
    gene_symbol = c("TP53", "EGFR"),
    n_sources = c(1L, 1L),
    combined_score = c(1, 0.5),
    rank = 1:2,
    sources = "opentargets"
  ))
  disease <- shiny::reactiveVal(list(id = "X", name = "demo"))
  controls <- shiny::reactiveVal(
    list(weights = c(opentargets = 1), coverage_bonus = 0.5, top_n = 2)
  )
  fake_curate <- function(ranked, disease_name, top_n = 30) {
    out <- tibble::tibble(
      gene_symbol = "TP53",
      include = TRUE,
      confidence = 0.9,
      rationale = "x"
    )
    attr(out, "ai_used") <- TRUE
    out
  }
  shiny::testServer(
    curation_server,
    args = list(
      ranked_reactive = ranked,
      disease_reactive = disease,
      controls_reactive = controls,
      curate_fn = fake_curate
    ),
    {
      session$setInputs(curate = 1)
      cur <- session$returned()
      expect_true(isTRUE(attr(cur, "ai_used")))
      expect_equal(cur$gene_symbol, "TP53")
    }
  )
})
