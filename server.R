# Shiny Server
function(input, output, session) {
  # --- Controls (return reactives) ---
  disease <- disease_search_server("disease")
  sources <- source_select_server("sources")
  controls <- ranking_controls_server("controls")

  # --- Pipeline: the only place network I/O fires (Run button) ---
  pipeline <- run_pipeline_server(
    "run",
    disease_reactive = disease,
    sources_reactive = sources
  )

  # --- Ranking: cheap reactive; re-runs on slider change, not on the network ---
  ranked <- reactive({
    req(pipeline())
    ctl <- controls()
    rank_genes(
      pipeline()$aggregated,
      weights = ctl$weights,
      coverage_bonus = ctl$coverage_bonus,
      evidence_ids = pipeline()$evidence_ids
    )
  })

  status <- reactive({
    req(pipeline())
    pipeline()$status
  })

  # --- Display + downstream modules ---
  source_status_server("status", status_reactive = status)
  results_table_server("results", ranked_reactive = ranked)

  curated <- curation_server(
    "curation",
    ranked_reactive = ranked,
    disease_reactive = disease,
    controls_reactive = controls
  )

  export_server(
    "export",
    ranked_reactive = ranked,
    curated_reactive = curated,
    disease_reactive = disease,
    status_reactive = status,
    controls_reactive = controls
  )

  # --- About page: live API-key status ---
  output$about_key_status <- renderUI({
    if (gemini_available()) {
      div(class = "alert alert-success", "GEMINI_API_KEY detected.")
    } else {
      div(
        class = "alert alert-warning",
        "No GEMINI_API_KEY set: AI curation falls back to top-N by rank."
      )
    }
  })
}
