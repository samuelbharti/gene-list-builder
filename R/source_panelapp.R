# Source adapter: Genomics England PanelApp ------------------------------------
#
# Disease-driven. PanelApp curates diagnostic gene panels with a green/amber/red
# confidence rating. The list endpoint's `search` param does not actually filter,
# so we fetch the panel index and token-match the disease name client-side, then
# pull the best-matching panel's green/amber genes.

PANELAPP_BASE <- "https://panelapp.genomicsengland.co.uk/api/v1/"

PANELAPP_CONFIDENCE <- c("3" = 1.0, "2" = 0.5, "1" = 0.25)
PANELAPP_COLOR <- c("3" = "green", "2" = "amber", "1" = "red")

# GET a PanelApp URL, returning parsed JSON (or NULL on error).
panelapp_get <- function(url, timeout = 20) {
  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_user_agent("gene-list-builder") |>
      httr2::req_timeout(timeout) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_perform(),
    error = function(e) NULL
  )
  if (is.null(resp)) {
    return(NULL)
  }
  tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) NULL
  )
}

# Meaningful lowercase tokens of a disease/panel name (drops short + generic
# words so "lung cancer" matches "Inherited lung cancer", not every panel).
panelapp_tokens <- function(text) {
  stop_words <- c(
    "disease",
    "diseases",
    "disorder",
    "disorders",
    "syndrome",
    "syndromes",
    "the",
    "and",
    "for",
    "with",
    "type",
    "familial",
    "hereditary",
    "inherited",
    "congenital",
    "related",
    "early",
    "onset",
    "adult",
    "childhood"
  )
  words <- unlist(strsplit(tolower(text %||% ""), "[^a-z0-9]+"))
  words <- words[nchar(words) >= 3 & !words %in% stop_words]
  unique(words)
}

# Walk the paginated panel index (capped) into a flat list of panels.
panelapp_collect_panels <- function(get_fn, max_pages = 8) {
  url <- paste0(PANELAPP_BASE, "panels/?page_size=100")
  panels <- list()
  page <- 0
  while (!is.null(url) && page < max_pages) {
    data <- get_fn(url)
    if (is.null(data)) {
      break
    }
    panels <- c(panels, data$results %||% list())
    url <- data$`next`
    page <- page + 1
  }
  panels
}

# Pick the panel whose name best matches the disease name, or NULL if no panel
# shares enough tokens.
panelapp_best_panel <- function(panels, disease_name) {
  tokens <- panelapp_tokens(disease_name)
  if (length(tokens) == 0 || length(panels) == 0) {
    return(NULL)
  }
  score <- vapply(
    panels,
    function(p) {
      hay <- panelapp_tokens(paste(
        p$name %||% "",
        paste(unlist(p$relevant_disorders %||% list()), collapse = " ")
      ))
      sum(tokens %in% hay)
    },
    integer(1)
  )
  best <- which.max(score)
  # Require a strict majority of disease tokens to match (and at least one), so
  # a generic panel sharing one broad token (e.g. only "cancer") is not treated
  # as disease-specific.
  min_match <- floor(length(tokens) / 2) + 1
  if (length(best) == 0 || score[[best]] < min_match) {
    return(NULL)
  }
  panels[[best]]
}

fetch_panelapp <- function(
  disease,
  gene_symbols = NULL,
  get_fn = panelapp_get,
  max_pages = 8
) {
  disease_name <- disease$name %||% ""
  if (!nzchar(disease_name)) {
    return(empty_gene_table())
  }

  panels <- panelapp_collect_panels(get_fn, max_pages = max_pages)
  panel <- panelapp_best_panel(panels, disease_name)
  if (is.null(panel)) {
    return(empty_gene_table())
  }

  detail <- get_fn(paste0(PANELAPP_BASE, "panels/", panel$id, "/"))
  genes <- detail$genes %||% list()
  if (length(genes) == 0) {
    return(empty_gene_table())
  }

  conf <- vapply(
    genes,
    function(g) as.character(g$confidence_level %||% NA),
    character(1)
  )
  keep <- conf %in% c("3", "2") # green + amber (diagnostic-grade) only
  genes <- genes[keep]
  conf <- conf[keep]
  if (length(genes) == 0) {
    return(empty_gene_table())
  }

  df <- data.frame(
    gene_symbol = vapply(
      genes,
      function(g) g$entity_name %||% NA_character_,
      character(1)
    ),
    source_score_raw = unname(PANELAPP_CONFIDENCE[conf]),
    evidence_type = paste0("panelapp_", unname(PANELAPP_COLOR[conf])),
    url = paste0(
      "https://panelapp.genomicsengland.co.uk/panels/",
      panel$id,
      "/"
    ),
    stringsAsFactors = FALSE
  )

  as_gene_table(df, "panelapp")
}
