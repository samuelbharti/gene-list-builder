# Module: disease search + resolution -----------------------------------------
# Resolves a free-text disease name (or pasted ontology id) to candidate terms
# and returns the selected disease as a reactive one-row list.

disease_search_ui <- function(id) {
  ns <- NS(id)
  tagList(
    textInput(
      ns("term"),
      "Disease",
      placeholder = "e.g. lung cancer or MONDO:0008903"
    ),
    actionButton(
      ns("resolve"),
      "Resolve disease",
      class = "btn-secondary",
      width = "100%"
    ),
    div(class = "mt-3", uiOutput(ns("candidates")))
  )
}

disease_search_server <- function(id, resolve_fn = resolve_disease) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    candidates <- eventReactive(input$resolve, {
      validate(need(
        nzchar(trimws(input$term %||% "")),
        "Enter a disease name."
      ))
      withProgress(message = "Resolving disease...", value = 0.5, {
        resolve_fn(input$term)
      })
    })

    output$candidates <- renderUI({
      cand <- candidates()
      if (nrow(cand) == 0) {
        return(div(
          class = "text-danger small",
          "No disease matched. Try a broader term or paste an EFO/MONDO id."
        ))
      }
      choices <- stats::setNames(
        cand$id,
        paste0(cand$name, "  [", cand$id, "]")
      )
      # A single compact dropdown (auto-selected to the top match) rather than a
      # stack of radio buttons, so resolving doesn't push the rest of the sidebar
      # controls down. The best match is pre-selected, so usually no extra click.
      selectInput(
        ns("choice"),
        "Matched disease",
        choices = choices,
        selected = cand$id[1],
        width = "100%"
      )
    })

    reactive({
      cand <- candidates()
      req(nrow(cand) > 0, input$choice)
      row <- cand[cand$id == input$choice, , drop = FALSE]
      if (nrow(row) == 0) {
        return(NULL)
      }
      as.list(row[1, ])
    })
  })
}
