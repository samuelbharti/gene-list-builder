# Builder page: sidebar controls + stepped result tabs ------------------------

builder_page <- bslib::page_sidebar(
  sidebar = bslib::sidebar(
    width = 340,
    title = "Build a gene list",
    disease_search_ui("disease"),
    tags$hr(),
    source_select_ui("sources"),
    tags$hr(),
    ranking_controls_ui("controls"),
    tags$hr(),
    run_pipeline_ui("run")
  ),
  bslib::navset_card_tab(
    id = "steps",
    bslib::nav_panel(
      "1. Sources",
      bslib::card_body(
        markdown(paste(
          "Per-source status for the most recent run. Each source returns genes",
          "in a common schema; failures degrade gracefully and the run continues."
        )),
        source_status_ui("status")
      )
    ),
    bslib::nav_panel(
      "2. Ranked",
      bslib::card_body(
        markdown(paste(
          "Genes ranked by weighted, source-normalized evidence with a",
          "multi-source coverage bonus. Tune the sidebar weights to re-rank",
          "instantly (no re-querying)."
        )),
        results_table_ui("results")
      )
    ),
    bslib::nav_panel(
      "3. AI curation",
      bslib::card_body(curation_ui("curation"))
    ),
    bslib::nav_panel(
      "4. Export",
      bslib::card_body(export_ui("export"))
    )
  )
)
