# Source adapter: ClinVar (via NCBI E-utilities) -------------------------------
#
# Disease-driven. Finds ClinVar records with pathogenic / likely-pathogenic
# classifications for the disease, then scores genes by how many such records
# name them. No key required; an optional ENTREZ_KEY raises the rate limit.

EUTILS_BASE <- "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

# GET an E-utilities endpoint as JSON, adding tool/email/api_key params and a
# throttle that respects NCBI's rate limits (3/s without a key, 10/s with one).
eutils_get <- function(endpoint, query, timeout = 20) {
  key <- Sys.getenv("ENTREZ_KEY")
  email <- Sys.getenv("ENTREZ_EMAIL")
  query <- c(
    query,
    list(tool = "gene-list-builder", retmode = "json")
  )
  if (nzchar(email)) {
    query$email <- email
  }
  if (nzchar(key)) {
    query$api_key <- key
  }

  resp <- tryCatch(
    httr2::request(paste0(EUTILS_BASE, endpoint)) |>
      httr2::req_url_query(!!!query) |>
      httr2::req_user_agent("gene-list-builder") |>
      httr2::req_timeout(timeout) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_throttle(rate = if (nzchar(key)) 9 else 2.5) |>
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

# ClinVar variation ids for pathogenic records associated with the disease term.
clinvar_esearch <- function(term, retmax = 300, get_fn = eutils_get) {
  data <- get_fn(
    "esearch.fcgi",
    list(
      db = "clinvar",
      term = term,
      retmax = retmax
    )
  )
  ids <- data$esearchresult$idlist
  if (is.null(ids)) character() else unlist(ids, use.names = FALSE)
}

# Gene symbols named by a set of ClinVar records (one entry per record-gene).
clinvar_esummary <- function(ids, chunk_size = 200, get_fn = eutils_get) {
  if (length(ids) == 0) {
    return(character())
  }
  chunks <- split(ids, ceiling(seq_along(ids) / chunk_size))
  symbols <- character()
  for (chunk in chunks) {
    data <- get_fn(
      "esummary.fcgi",
      list(
        db = "clinvar",
        id = paste(chunk, collapse = ",")
      )
    )
    result <- data$result
    if (is.null(result)) {
      next
    }
    uids <- unlist(result$uids %||% list(), use.names = FALSE)
    for (uid in uids) {
      genes <- result[[uid]]$genes %||% list()
      for (g in genes) {
        sym <- g$symbol %||% NA_character_
        if (!is.na(sym)) symbols <- c(symbols, sym)
      }
    }
  }
  symbols
}

fetch_clinvar <- function(
  disease,
  gene_symbols = NULL,
  retmax = 300,
  esearch_fn = clinvar_esearch,
  esummary_fn = clinvar_esummary
) {
  disease_name <- disease$name %||% ""
  if (!nzchar(disease_name)) {
    return(empty_gene_table())
  }

  term <- paste0("\"", disease_name, "\"[dis] AND clinsig_pathogenic[Prop]")
  ids <- esearch_fn(term, retmax = retmax)
  if (length(ids) == 0) {
    return(empty_gene_table())
  }

  symbols <- esummary_fn(ids)
  if (length(symbols) == 0) {
    return(empty_gene_table())
  }

  counts <- as.data.frame(
    table(gene_symbol = symbols),
    stringsAsFactors = FALSE
  )
  names(counts)[2] <- "n"
  df <- data.frame(
    gene_symbol = counts$gene_symbol,
    source_score_raw = counts$n,
    n_evidence = as.integer(counts$n),
    evidence_type = "clinvar_pathogenic",
    url = paste0(
      "https://www.ncbi.nlm.nih.gov/clinvar/?term=",
      utils::URLencode(counts$gene_symbol, reserved = TRUE),
      "%5Bgene%5D"
    ),
    stringsAsFactors = FALSE
  )

  as_gene_table(df, "clinvar")
}
