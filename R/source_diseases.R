# Source adapter: DISEASES (Jensen Lab) ----------------------------------------
#
# Disease-driven. Text-mined + curated disease-gene associations with confidence
# scores (0-5). The API is keyed by Disease Ontology id (DOID), which we obtain
# from the Open Targets disease cross-references.

DISEASES_BASE <- "https://api.jensenlab.org/"

# Query one DISEASES channel ("Knowledge" = curated, "Textmining" = mined).
# Returns a data frame of (gene_symbol, score, url); empty on error/no data.
glb_diseases_channel <- function(
  doid,
  channel = "Knowledge",
  limit = 300,
  get_fn = diseases_get
) {
  url <- paste0(
    DISEASES_BASE,
    channel,
    "?type1=-26&id1=",
    utils::URLencode(doid, reserved = TRUE),
    "&type2=9606&limit=",
    limit,
    "&format=json"
  )
  body <- get_fn(url)
  # The API returns a JSON array whose first element maps ENSP id -> entry.
  entries <- if (is.list(body) && length(body) >= 1) body[[1]] else NULL
  if (is.null(entries) || length(entries) == 0) {
    return(data.frame())
  }
  data.frame(
    gene_symbol = vapply(
      entries,
      function(e) as.character(e$name %||% NA),
      character(1)
    ),
    score = vapply(
      entries,
      function(e) as.numeric(e$score %||% NA),
      numeric(1)
    ),
    url = vapply(
      entries,
      function(e) as.character(e$url %||% NA),
      character(1)
    ),
    stringsAsFactors = FALSE
  )
}

# GET a DISEASES URL, returning parsed JSON (or NULL on error).
diseases_get <- function(url, timeout = 20) {
  biohttp::body_or_null(diseases_get_env(url, timeout))
}

# Envelope-returning form.
diseases_get_env <- function(url, timeout = 20) {
  glb_get(url, source = "DISEASES", timeout = timeout)
}

fetch_diseases <- function(
  disease,
  gene_symbols = NULL,
  doid_fn = ot_disease_xref_id,
  channel_fn = glb_diseases_channel
) {
  efo <- disease$id %||% ""
  doid <- if (!is.null(disease$doid)) disease$doid else doid_fn(efo, "DOID")
  if (is.null(doid) || is.na(doid) || !nzchar(doid)) {
    return(empty_gene_table())
  }

  knowledge <- channel_fn(doid, "Knowledge")
  textmining <- channel_fn(doid, "Textmining")
  both <- dplyr::bind_rows(knowledge, textmining)
  if (nrow(both) == 0) {
    return(empty_gene_table())
  }

  # Keep the strongest score per gene across the two channels.
  agg <- both |>
    dplyr::filter(
      !is.na(.data$gene_symbol),
      nzchar(.data$gene_symbol),
      is.finite(.data$score)
    ) |>
    dplyr::group_by(.data$gene_symbol) |>
    dplyr::summarise(
      source_score_raw = max(.data$score),
      url = first_non_na(.data$url),
      .groups = "drop"
    )
  if (nrow(agg) == 0) {
    return(empty_gene_table())
  }
  agg$evidence_type <- "diseases_association"

  as_gene_table(agg, "diseases")
}
