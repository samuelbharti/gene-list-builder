# Module: per-source status -----------------------------------------------------
# Renders a value box per source (ok/error, gene count, latency).

source_status_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("boxes"))
}

source_status_server <- function(id, status_reactive) {
  moduleServer(id, function(input, output, session) {
    output$boxes <- renderUI({
      status <- status_reactive()
      validate(need(
        !is.null(status) && nrow(status) > 0,
        "Build a gene list to query sources."
      ))

      boxes <- lapply(seq_len(nrow(status)), function(i) {
        ok <- isTRUE(status$ok[i])
        bslib::value_box(
          title = status$label[i],
          value = paste0(status$n_genes[i], " genes"),
          theme = if (ok) "success" else "danger",
          p(status$message[i]),
          p(paste0(status$latency_ms[i], " ms"))
        )
      })

      do.call(
        bslib::layout_column_wrap,
        c(list(width = "220px"), boxes)
      )
    })
  })
}
