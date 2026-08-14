# Shared HTTP transport ---------------------------------------------------------
#
# Every source adapter used to carry its own near-identical 15-line httr2
# pipeline (seven copies), each of which collapsed *every* failure to NULL via
# `tryCatch(..., error = function(e) NULL)`. That made a 500, a DNS failure, a
# timeout and a genuinely empty result indistinguishable, so a source that was
# completely down surfaced in the UI as "ok, 0 genes".
#
# These helpers delegate to {biohttp}, which returns a normalised *envelope*
# rather than raising, and distinguishes transport failure from non-success
# status from an unreadable body. That also brings per-host circuit breaking,
# a transient-only retry predicate, throttling and a success-only response
# cache, none of which the hand-rolled version had.
#
# Envelope shape: list(ok, status, http, data, source, error, detail, ts) where
# `status` is one of biohttp::STATUS_LEVELS.
#
# ALWAYS call these as biohttp::/bioclients:: qualified. Never attach either
# package: this app sources into the global environment, so a global would
# shadow the namespace.

# POST a GraphQL query. Returns an envelope. A GraphQL-level `errors` payload
# (HTTP 200 with an error body) is converted into an error envelope, so callers
# do not have to remember to check for it. Four of the seven original wrappers
# forgot to.
glb_graphql <- function(
  url,
  query,
  variables = list(),
  source = "API",
  timeout = 20,
  max_tries = 3
) {
  res <- biohttp::post_json(
    url,
    body = list(query = query, variables = variables),
    source = source,
    timeout = timeout,
    max_tries = max_tries
  )
  gql_err <- biohttp::graphql_error(res, source)
  if (!is.null(gql_err)) {
    return(gql_err)
  }
  res
}

# GET JSON. Returns an envelope. `secret_query` is applied at dispatch only, so
# API keys stay out of cache keys and out of error text.
glb_get <- function(
  base_url,
  path = NULL,
  query = list(),
  source = "API",
  timeout = 20,
  max_tries = 3,
  throttle = NULL,
  secret_query = NULL
) {
  biohttp::get_json(
    base_url,
    path = path,
    query = query,
    source = source,
    timeout = timeout,
    max_tries = max_tries,
    throttle = throttle,
    secret_query = secret_query
  )
}

# The `data` field of a GraphQL envelope, or NULL. Preserves the exact contract
# the old hand-rolled wrappers had, so adapters and their injected test stubs
# keep working unchanged while the status travels separately.
glb_graphql_data <- function(res) {
  body <- biohttp::body_or_null(res)
  if (is.null(body)) {
    return(NULL)
  }
  body$data
}
