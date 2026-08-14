# Aggregate per-source gene tables into one row per gene -----------------------

# Annotate each gene with how HGNC sees its symbol. REPORTING ONLY: this adds a
# column and changes no score, no ranking and no dedupe.
#
# Why report rather than repair. aggregate_sources() dedupes on `gene_symbol`,
# and as_gene_table() only uppercases, so two sources naming the same gene
# differently (KMT2A vs the legacy MLL) split into two rows, halving the
# evidence and understating n_sources. The obvious fix is
# biobouncer::repair_id(), but its suggestions come from two routes: an
# authoritative retired/alias map AND a bounded fuzzy search, and report_id()
# does not say which. Verified behaviour:
#
#   ""        -> "AR"       invents a gene from an empty string
#   ORF1AB    -> OR11A1     fuzzy guess, wrong
#   C9ORF72   -> C9orf72    case regression, re-splits the key
#   MLL       -> KMT2A      correct and authoritative
#
# Blanket repair would therefore trade a dedupe bug for phantom genes. This
# column measures how much alias-splitting the corpus actually has, so the
# decision to repair (and how) can be made on evidence rather than hope.
#
# Values: "valid" | "alias of <X>" | "unknown". Falls open to NA if biobouncer
# is unavailable, so this can never break aggregation.
symbol_status <- function(symbols) {
  n <- length(symbols)
  if (n == 0 || !requireNamespace("biobouncer", quietly = TRUE)) {
    return(rep(NA_character_, n))
  }
  info <- tryCatch(
    biobouncer::report_id(symbols, "hgnc", how = "cache"),
    error = function(e) NULL
  )
  if (is.null(info)) {
    return(rep(NA_character_, n))
  }
  as.character(ifelse(
    info$valid %in% TRUE,
    "valid",
    ifelse(
      !is.na(info$suggestion),
      paste0("alias of ", info$suggestion),
      "unknown"
    )
  ))
}

# Empty aggregated table (no score_* columns since no sources contributed).
empty_aggregated_table <- function() {
  tibble::tibble(
    gene_symbol = character(),
    ensembl_id = character(),
    entrez_id = character(),
    n_sources = integer(),
    sources = character(),
    evidence = character()
  )
}

# Normalize one source's raw scores to 0..1 according to its method:
#   "passthrough" - scores already on 0..1 (e.g. Open Targets association score)
#   "rank"        - rank-normalize (robust for count-based / heavy-tailed scores)
#   "rank_desc"   - rank-normalize where LOWER raw is better (e.g. gnomAD LOEUF)
normalize_source_scores <- function(raw, method = "rank") {
  if (identical(method, "passthrough")) {
    clamp01(raw)
  } else if (identical(method, "rank_desc")) {
    normalize_rank(-safe_num(raw))
  } else {
    normalize_rank(raw)
  }
}

# `per_source`  - (named) list of canonical gene tibbles, one per source.
# `norm_methods`- optional named character vector mapping source_id -> method.
# `evidence_ids`- source ids that count as disease *evidence* (drive n_sources and
#                 the coverage bonus). Sources not listed (e.g. gnomAD/Pharos
#                 annotations) still contribute a score_<id> column but do not
#                 inflate coverage. NULL means "treat every source as evidence".
#
# Returns one row per gene with provenance columns plus a `score_<source_id>`
# column (the normalized score, NA where the gene is absent from that source).
aggregate_sources <- function(
  per_source,
  norm_methods = NULL,
  evidence_ids = NULL
) {
  combined <- dplyr::bind_rows(per_source)
  if (nrow(combined) == 0) {
    return(empty_aggregated_table())
  }

  # Per-source normalization of raw scores into 0..1.
  parts <- split(combined, combined$source_id)
  parts <- lapply(parts, function(df) {
    sid <- df$source_id[[1]]
    method <- if (!is.null(norm_methods) && sid %in% names(norm_methods)) {
      norm_methods[[sid]]
    } else {
      "rank"
    }
    df$source_score_norm <- normalize_source_scores(df$source_score_raw, method)
    df
  })
  combined <- dplyr::bind_rows(parts)

  # Flag which rows come from evidence (vs annotation-only) sources.
  combined$is_evidence <- if (is.null(evidence_ids)) {
    TRUE
  } else {
    combined$source_id %in% evidence_ids
  }

  # One row per (gene, source): keep the strongest normalized score.
  combined <- combined |>
    dplyr::group_by(.data$gene_symbol, .data$source_id) |>
    dplyr::slice_max(
      order_by = .data$source_score_norm,
      n = 1,
      with_ties = FALSE,
      na_rm = FALSE
    ) |>
    dplyr::ungroup()

  # Wide per-source normalized score columns.
  wide <- combined |>
    dplyr::select("gene_symbol", "source_id", "source_score_norm") |>
    tidyr::pivot_wider(
      names_from = "source_id",
      values_from = "source_score_norm",
      names_prefix = "score_"
    )

  # Per-gene provenance. n_sources and `sources` count evidence sources only.
  prov <- combined |>
    dplyr::group_by(.data$gene_symbol) |>
    dplyr::summarise(
      ensembl_id = first_non_na(.data$ensembl_id),
      entrez_id = first_non_na(.data$entrez_id),
      n_sources = dplyr::n_distinct(
        .data$source_id[.data$is_evidence]
      ),
      sources = paste(
        sort(unique(.data$source_id[.data$is_evidence])),
        collapse = ", "
      ),
      evidence = paste(
        sort(unique(stats::na.omit(.data$evidence_type))),
        collapse = ", "
      ),
      .groups = "drop"
    )

  # Drop annotation-only genes: a gene with no evidence source (e.g. one a
  # gene-driven annotation source canonicalized to a symbol absent from every
  # evidence source) must not enter the candidate list.
  prov <- prov[prov$n_sources > 0, , drop = FALSE]

  # Diagnostic only: how HGNC sees each symbol. Never used for scoring.
  prov$symbol_status <- symbol_status(prov$gene_symbol)

  dplyr::left_join(prov, wide, by = "gene_symbol")
}
