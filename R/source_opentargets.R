# Source adapter: Open Targets associated targets -----------------------------
#
# Disease-driven source. Returns the targets associated with a disease, scored
# by the Open Targets overall association score (already on 0..1).

OT_ASSOC_QUERY <- "
query Assoc($efoId: String!, $size: Int!) {
  disease(efoId: $efoId) {
    id
    name
    associatedTargets(page: {index: 0, size: $size}) {
      count
      rows {
        score
        target { id approvedSymbol }
      }
    }
  }
}"

# `disease` is a one-row data frame / list with at least `id`. `gene_symbols` is
# ignored (this is a disease-driven source). Returns a canonical gene tibble.
fetch_opentargets <- function(
  disease,
  gene_symbols = NULL,
  limit = 200,
  graphql_fn = ot_graphql
) {
  efo <- disease$id %||% NULL
  if (is.null(efo) || !nzchar(efo)) {
    return(empty_gene_table())
  }

  data <- graphql_fn(OT_ASSOC_QUERY, list(efoId = efo, size = limit))
  rows <- data$disease$associatedTargets$rows
  if (is.null(rows) || length(rows) == 0) {
    return(empty_gene_table())
  }

  ensembl <- vapply(
    rows,
    function(r) r$target$id %||% NA_character_,
    character(1)
  )
  df <- data.frame(
    gene_symbol = vapply(
      rows,
      function(r) r$target$approvedSymbol %||% NA_character_,
      character(1)
    ),
    ensembl_id = ensembl,
    source_score_raw = vapply(
      rows,
      function(r) as.numeric(r$score %||% NA),
      numeric(1)
    ),
    evidence_type = "overall_association",
    url = ifelse(
      is.na(ensembl),
      NA_character_,
      paste0("https://platform.opentargets.org/target/", ensembl)
    ),
    stringsAsFactors = FALSE
  )

  as_gene_table(df, "opentargets")
}
