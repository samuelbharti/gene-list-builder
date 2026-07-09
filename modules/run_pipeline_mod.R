# Module: pipeline orchestrator -------------------------------------------------
# Owns the Run button. This is the ONLY place network I/O fires: it snapshots the
# disease + sources at click time, queries sources with a progress bar, and
# aggregates. Returns a reactive list: per_source, status, aggregated, etc.
# `run_sources_fn` is injectable for tests.

run_pipeline_ui <- function(id) {
  ns <- NS(id)
  tagList(
    checkboxInput(ns("force"), "Ignore cache (force refresh)", value = FALSE),
    actionButton(
      ns("run"),
      "Build gene list",
      class = "btn-primary",
      width = "100%"
    )
  )
}

run_pipeline_server <- function(
  id,
  disease_reactive,
  sources_reactive,
  run_sources_fn = run_sources
) {
  moduleServer(id, function(input, output, session) {
    eventReactive(input$run, {
      # disease_reactive derives from an eventReactive that errors before a
      # disease is resolved; catch that so the guidance message can show.
      disease <- tryCatch(disease_reactive(), error = function(e) NULL)
      validate(need(!is.null(disease), "Resolve and select a disease first."))
      sources <- sources_reactive()
      validate(need(length(sources) > 0, "Select at least one data source."))

      n <- length(sources)
      res <- withProgress(message = "Building gene list", value = 0, {
        run_sources_fn(
          disease,
          sources,
          force = isTRUE(input$force),
          on_progress = function(detail) incProgress(1 / n, detail = detail)
        )
      })

      evidence_ids <- evidence_source_ids(sources)
      aggregated <- aggregate_sources(
        res$results,
        norm_methods = source_norm_methods(sources),
        evidence_ids = evidence_ids
      )

      list(
        per_source = res$results,
        status = res$status,
        aggregated = aggregated,
        evidence_ids = evidence_ids,
        n_sources = n,
        disease = disease
      )
    })
  })
}
