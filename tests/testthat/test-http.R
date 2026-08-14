# Transport layer tests.
#
# Before the biohttp migration these seven wrappers had ZERO coverage: every
# test fake was injected one level above them. That is precisely why the bug
# below survived, so these tests target the transport itself.

test_that("glb_status_record keeps the most severe status seen", {
  glb_status_reset()
  expect_null(glb_status_worst())

  glb_status_record(biohttp::status_ok(list(a = 1), source = "S"))
  expect_equal(glb_status_worst()$status, "ok")

  # A later, more severe status wins.
  glb_status_record(biohttp::status_timeout(source = "S"))
  expect_equal(glb_status_worst()$status, "timeout")

  # A later, less severe status must NOT overwrite it. A source that makes many
  # calls (PanelApp's page walk, DGIdb's chunks) must report the worst one.
  glb_status_record(biohttp::status_ok(list(a = 1), source = "S"))
  expect_equal(glb_status_worst()$status, "timeout")

  glb_status_reset()
  expect_null(glb_status_worst())
})

test_that("glb_graphql turns a GraphQL errors payload into an error envelope", {
  # HTTP 200 with an `errors` body is the case gnomAD and Pharos silently
  # ignored, returning body$data unconditionally so a query error looked
  # exactly like an empty result.
  res <- biohttp::status_ok(
    list(errors = list(list(message = "bad field"))),
    source = "T"
  )
  err <- biohttp::graphql_error(res, "T")
  expect_false(is.null(err))
  expect_equal(err$status, "error")

  # And the data view of an errored envelope is NULL, never a partial body.
  expect_null(glb_graphql_data(err))
})

test_that("glb_graphql_data returns NULL for a failed envelope", {
  expect_null(glb_graphql_data(biohttp::status_timeout(source = "T")))
  expect_null(glb_graphql_data(biohttp::status_error(source = "T")))
  expect_equal(
    glb_graphql_data(biohttp::status_ok(
      list(data = list(x = 1)),
      source = "T"
    )),
    list(x = 1)
  )
})

test_that("an unreachable host yields an error envelope, not a silent NULL", {
  skip_on_cran()
  glb_status_reset()
  # .invalid is reserved by RFC 2606, so this fails at DNS without touching a
  # real network and without depending on the machine being online.
  res <- glb_graphql(
    "https://gene-list-builder.invalid/graphql",
    query = "query { x }",
    source = "Broken"
  )
  expect_false(isTRUE(res$ok))
  expect_true(res$status %in% biohttp::STATUS_LEVELS)
  expect_false(identical(res$status, "ok"))
  # The failure was recorded for the registry to pick up.
  expect_equal(glb_status_worst()$status, res$status)
  glb_status_reset()
})

test_that("a source that fails reports 'error', NOT 'no genes returned'", {
  skip_on_cran()
  # This is the regression test for the headline bug. Previously every wrapper
  # swallowed failures to NULL, the adapter degraded to an empty table, and
  # .run_one reported ok = TRUE / "no genes returned" -- so a dead API was
  # indistinguishable from a disease with no associated genes, and the user
  # could export a silently incomplete gene list.
  broken <- list(
    id = "broken",
    label = "Broken source",
    needs = "disease",
    role = "evidence",
    fetch_fn = function(disease, gene_symbols = NULL) {
      glb_graphql(
        "https://gene-list-builder.invalid/graphql",
        query = "query { x }",
        source = "Broken source"
      )
      empty_gene_table()
    }
  )

  withr::local_envvar(GLB_CACHE_DIR = withr::local_tempdir())
  out <- .run_one(
    broken,
    disease = list(id = "MONDO_0000001"),
    gene_symbols = NULL,
    force = TRUE
  )

  expect_equal(nrow(out$genes), 0)
  expect_false(out$status$ok)
  expect_false(identical(out$status$status, "no_data"))
  expect_true(out$status$status %in% c("error", "timeout"))
})

test_that("a source that genuinely finds nothing reports 'no_data'", {
  empty <- list(
    id = "empty",
    label = "Empty source",
    needs = "disease",
    role = "evidence",
    fetch_fn = function(disease, gene_symbols = NULL) empty_gene_table()
  )

  withr::local_envvar(GLB_CACHE_DIR = withr::local_tempdir())
  out <- .run_one(
    empty,
    disease = list(id = "MONDO_0000001"),
    gene_symbols = NULL,
    force = TRUE
  )

  expect_equal(out$status$status, "no_data")
  expect_false(out$status$ok)
  expect_equal(out$status$message, "no genes returned")
})

test_that(".status_row derives ok from status so they cannot disagree", {
  src <- list(id = "x", label = "X")
  expect_true(.status_row(src, "ok", 3L, 10, "ok")$ok)
  for (s in setdiff(biohttp::STATUS_LEVELS, "ok")) {
    expect_false(.status_row(src, s, 0L, 10, "m")$ok)
  }
})

test_that("every status level maps to a value-box theme and a label", {
  for (s in biohttp::STATUS_LEVELS) {
    expect_false(is.na(GLB_STATUS_THEME[s]), info = s)
    expect_false(is.na(GLB_STATUS_LABEL[s]), info = s)
  }
  # The distinction that matters to the user.
  expect_equal(unname(GLB_STATUS_THEME[["ok"]]), "success")
  expect_equal(unname(GLB_STATUS_THEME[["no_data"]]), "secondary")
  expect_equal(unname(GLB_STATUS_THEME[["error"]]), "danger")
})

test_that("a bioclients-backed adapter records its failure status", {
  # Regression test. bioclients calls biohttp directly, bypassing
  # glb_graphql()/glb_get(), so migrating the adapters silently reintroduced
  # the original bug for those sources: a down API reported "no_data" (the
  # source answered, nothing found) rather than "error". Caught live against a
  # real Pharos 502. Every bioclients call must go through glb_client_body().
  src <- list(
    id = "pharos",
    label = "Pharos",
    needs = "genes",
    role = "annotation",
    fetch_fn = function(disease, gene_symbols = NULL) {
      fetch_pharos(
        gene_symbols = gene_symbols,
        client_fn = function(symbols, ...) {
          biohttp::status_error(source = "Pharos", http = 502L)
        }
      )
    }
  )

  withr::local_envvar(GLB_CACHE_DIR = withr::local_tempdir())
  out <- .run_one(
    src,
    disease = list(id = "MONDO_1"),
    gene_symbols = c("EGFR"),
    force = TRUE
  )

  expect_equal(nrow(out$genes), 0)
  expect_equal(out$status$status, "error")
  expect_false(identical(out$status$status, "no_data"))
})

test_that("a bioclients-backed adapter with a real empty answer is no_data", {
  src <- list(
    id = "pharos",
    label = "Pharos",
    needs = "genes",
    role = "annotation",
    fetch_fn = function(disease, gene_symbols = NULL) {
      fetch_pharos(
        gene_symbols = gene_symbols,
        client_fn = function(symbols, ...) {
          biohttp::status_ok(
            tibble::tibble(
              symbol = symbols,
              tdl = NA_character_,
              source_url = NA_character_
            ),
            source = "Pharos"
          )
        }
      )
    }
  )

  withr::local_envvar(GLB_CACHE_DIR = withr::local_tempdir())
  out <- .run_one(
    src,
    disease = list(id = "MONDO_1"),
    gene_symbols = c("EGFR"),
    force = TRUE
  )
  expect_equal(out$status$status, "no_data")
})
