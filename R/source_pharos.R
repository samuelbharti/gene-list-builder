# Source adapter: Pharos / TCRD target development level (annotation) ----------
#
# Gene-driven *prioritizer* (role = "annotation"): scores candidate genes by
# their Target Development Level (TDL) - how far along the druggability spectrum
# a target is (Tclin > Tchem > Tbio > Tdark). Does not add genes or count toward
# coverage.

PHAROS_URL <- "https://pharos-api.ncats.io/graphql"

PHAROS_TDL_SCORE <- c(
  Tclin = 1.0,
  Tchem = 0.75,
  Tbio = 0.5,
  Tdark = 0.25
)

PHAROS_TARGETS_QUERY <- "
query Targets($syms: [String!]) {
  targets(targets: $syms) { targets { sym tdl } }
}"

# POST a GraphQL query to Pharos; returns parsed `data` or NULL on error.
pharos_graphql <- function(query, variables = list(), timeout = 30) {
  resp <- tryCatch(
    httr2::request(PHAROS_URL) |>
      httr2::req_user_agent("gene-list-builder") |>
      httr2::req_timeout(timeout) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_body_json(list(query = query, variables = variables)) |>
      httr2::req_perform(),
    error = function(e) NULL
  )
  if (is.null(resp)) {
    return(NULL)
  }
  body <- tryCatch(
    httr2::resp_body_json(resp, simplifyVector = FALSE),
    error = function(e) NULL
  )
  body$data
}

fetch_pharos <- function(
  disease = NULL,
  gene_symbols = NULL,
  graphql_fn = pharos_graphql
) {
  symbols <- unique(toupper(trimws(gene_symbols %||% character())))
  symbols <- symbols[nzchar(symbols)]
  if (length(symbols) == 0) {
    return(empty_gene_table())
  }

  data <- graphql_fn(PHAROS_TARGETS_QUERY, list(syms = as.list(symbols)))
  targets <- data$targets$targets
  if (is.null(targets) || length(targets) == 0) {
    return(empty_gene_table())
  }

  tdl <- vapply(targets, function(t) as.character(t$tdl %||% NA), character(1))
  df <- data.frame(
    gene_symbol = vapply(
      targets,
      function(t) as.character(t$sym %||% NA),
      character(1)
    ),
    source_score_raw = unname(PHAROS_TDL_SCORE[tdl]),
    evidence_type = paste0("pharos_", tolower(tdl)),
    stringsAsFactors = FALSE
  )
  df <- df[!is.na(df$source_score_raw), , drop = FALSE]
  if (nrow(df) == 0) {
    return(empty_gene_table())
  }
  df$url <- paste0("https://pharos.nih.gov/targets/", df$gene_symbol)

  as_gene_table(df, "pharos")
}
