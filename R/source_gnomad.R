# Source adapter: gnomAD gene constraint (annotation) --------------------------
#
# Gene-driven *prioritizer* (role = "annotation"): it does not add new genes or
# count toward coverage, but scores candidate genes by loss-of-function
# intolerance (LOEUF, gnomAD `oe_lof_upper`). Lower LOEUF = more constrained =
# higher priority, handled by the "rank_desc" normalization. The gnomAD API
# takes one gene per query, so we batch many genes per request using aliases.

GNOMAD_URL <- "https://gnomad.broadinstitute.org/api"

# POST a GraphQL query to gnomAD; returns parsed `data` or NULL on error.
gnomad_graphql <- function(query, timeout = 30) {
  resp <- tryCatch(
    httr2::request(GNOMAD_URL) |>
      httr2::req_user_agent("gene-list-builder") |>
      httr2::req_timeout(timeout) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_body_json(list(query = query)) |>
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

fetch_gnomad <- function(
  disease = NULL,
  gene_symbols = NULL,
  chunk_size = 20,
  graphql_fn = gnomad_graphql
) {
  symbols <- unique(toupper(trimws(gene_symbols %||% character())))
  symbols <- symbols[grepl("^[A-Za-z0-9._-]+$", symbols)]
  if (length(symbols) == 0) {
    return(empty_gene_table())
  }

  chunks <- split(symbols, ceiling(seq_along(symbols) / chunk_size))
  rows <- list()
  for (chunk in chunks) {
    aliases <- vapply(
      seq_along(chunk),
      function(i) {
        sprintf(
          paste0(
            'g%d: gene(gene_symbol: "%s", reference_genome: GRCh38) ',
            "{ symbol gnomad_constraint { oe_lof_upper pli } }"
          ),
          i,
          chunk[[i]]
        )
      },
      character(1)
    )
    data <- graphql_fn(paste0("{\n", paste(aliases, collapse = "\n"), "\n}"))
    if (is.null(data)) {
      next
    }
    for (entry in data) {
      if (is.null(entry)) {
        next
      }
      con <- entry$gnomad_constraint
      loeuf <- if (is.null(con)) NULL else con$oe_lof_upper
      sym <- entry$symbol
      if (!is.null(sym) && !is.null(loeuf)) {
        rows[[length(rows) + 1]] <- list(
          gene_symbol = sym,
          loeuf = as.numeric(loeuf)
        )
      }
    }
  }
  if (length(rows) == 0) {
    return(empty_gene_table())
  }

  df <- data.frame(
    gene_symbol = vapply(rows, function(r) r$gene_symbol, character(1)),
    source_score_raw = vapply(rows, function(r) r$loeuf, numeric(1)),
    evidence_type = "gnomad_constraint",
    stringsAsFactors = FALSE
  )
  df$url <- paste0("https://gnomad.broadinstitute.org/gene/", df$gene_symbol)

  as_gene_table(df, "gnomad")
}
