# Source adapter: DGIdb drug-gene interactions ---------------------------------
#
# DGIdb is gene-centric (it maps genes to drug interactions), so it is a
# gene-driven source: it annotates candidate genes seeded by the disease-driven
# sources with druggability evidence. The raw score is the number of known drug
# interactions; rank-normalized at aggregation time.

DGIDB_GRAPHQL_URL <- "https://dgidb.org/api/graphql"

DGIDB_GENES_QUERY <- "
query Genes($names: [String!]!) {
  genes(names: $names) {
    nodes {
      name
      conceptId
      interactions { interactionScore }
    }
  }
}"

dgidb_graphql <- function(query, variables = list(), timeout = 20) {
  glb_graphql_data(dgidb_graphql_env(query, variables, timeout))
}

# Envelope-returning form, for callers that need the failure reason.
dgidb_graphql_env <- function(query, variables = list(), timeout = 20) {
  glb_graphql(
    DGIDB_GRAPHQL_URL,
    query = query,
    variables = variables,
    source = "DGIdb",
    timeout = timeout
  )
}

# `gene_symbols` is the union of symbols found by disease-driven sources.
# Returns a canonical gene tibble scored by drug-interaction count.
fetch_dgidb <- function(
  disease = NULL,
  gene_symbols = NULL,
  chunk_size = 100,
  graphql_fn = dgidb_graphql
) {
  gene_symbols <- unique(toupper(trimws(gene_symbols %||% character())))
  gene_symbols <- gene_symbols[nzchar(gene_symbols)]
  if (length(gene_symbols) == 0) {
    return(empty_gene_table())
  }

  chunks <- split(
    gene_symbols,
    ceiling(seq_along(gene_symbols) / chunk_size)
  )

  nodes <- list()
  for (chunk in chunks) {
    data <- graphql_fn(DGIDB_GENES_QUERY, list(names = as.list(chunk)))
    nodes <- c(nodes, data$genes$nodes %||% list())
  }
  if (length(nodes) == 0) {
    return(empty_gene_table())
  }

  n_interactions <- vapply(
    nodes,
    function(n) length(n$interactions %||% list()),
    integer(1)
  )
  keep <- n_interactions > 0
  nodes <- nodes[keep]
  n_interactions <- n_interactions[keep]
  if (length(nodes) == 0) {
    return(empty_gene_table())
  }

  concept <- vapply(
    nodes,
    function(n) n$conceptId %||% NA_character_,
    character(1)
  )
  df <- data.frame(
    gene_symbol = vapply(
      nodes,
      function(n) n$name %||% NA_character_,
      character(1)
    ),
    source_score_raw = as.numeric(n_interactions),
    n_evidence = n_interactions,
    evidence_type = "drug_interaction",
    url = ifelse(
      is.na(concept),
      NA_character_,
      paste0("https://dgidb.org/genes/", concept)
    ),
    stringsAsFactors = FALSE
  )

  as_gene_table(df, "dgidb")
}
