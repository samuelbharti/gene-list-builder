# Open Targets Platform GraphQL client -----------------------------------------

OT_GRAPHQL_URL <- "https://api.platform.opentargets.org/api/v4/graphql"

# Execute a GraphQL query against the Open Targets Platform API. Returns the
# parsed `data` list, or NULL on transport/GraphQL error (callers degrade to an
# empty result rather than crash).
ot_graphql <- function(query, variables = list(), timeout = 20) {
  resp <- tryCatch(
    httr2::request(OT_GRAPHQL_URL) |>
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
  if (is.null(body) || !is.null(body$errors)) {
    return(NULL)
  }
  body$data
}

OT_XREFS_QUERY <- "
query Xrefs($efoId: String!) {
  disease(efoId: $efoId) { id name dbXRefs }
}"

# Cross-reference ids for a disease (e.g. "DOID:1324", "UMLS:C0242379"). Used to
# translate the resolved MONDO/EFO id into the identifier another source needs.
ot_disease_xrefs <- function(efo_id, graphql_fn = ot_graphql) {
  if (is.null(efo_id) || !nzchar(efo_id)) {
    return(character())
  }
  data <- graphql_fn(OT_XREFS_QUERY, list(efoId = efo_id))
  xrefs <- data$disease$dbXRefs
  if (is.null(xrefs)) {
    return(character())
  }
  unlist(xrefs, use.names = FALSE)
}

# First cross-reference id with the given prefix (e.g. ot_disease_xref_id(id,
# "DOID") -> "DOID:1324"), or NA if none.
ot_disease_xref_id <- function(efo_id, prefix, graphql_fn = ot_graphql) {
  xrefs <- ot_disease_xrefs(efo_id, graphql_fn = graphql_fn)
  hit <- grep(paste0("^", prefix, ":"), xrefs, value = TRUE, ignore.case = TRUE)
  if (length(hit) == 0) NA_character_ else hit[[1]]
}
