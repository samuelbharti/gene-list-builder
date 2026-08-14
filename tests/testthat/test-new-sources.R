# Tests for the additional source adapters, with all network calls injected.

test_that("fetch_panelapp() matches a panel and maps confidence, dropping red", {
  index_fn <- function(max_pages, page_size, ...) {
    biohttp::status_ok(
      tibble::tibble(
        id = c(1L, 2L),
        name = c("Long QT syndrome", "Cystic fibrosis"),
        version = c("1.0", "1.0"),
        disorders = list(list("R1"), list()),
        source_url = c("https://p/1/", "https://p/2/")
      ),
      source = "PanelApp"
    )
  }
  panel_fn <- function(panel_id, ...) {
    expect_equal(panel_id, 1L)
    biohttp::status_ok(
      tibble::tibble(
        symbol = c("KCNQ1", "KCNH2", "LOWCONF"),
        confidence = c(3L, 2L, 1L),
        level = c("green", "amber", "red"),
        hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
        source_url = rep("https://p/1/", 3)
      ),
      source = "PanelApp"
    )
  }
  gt <- fetch_panelapp(
    list(name = "long QT syndrome"),
    index_fn = index_fn,
    panel_fn = panel_fn
  )
  expect_setequal(gt$gene_symbol, c("KCNQ1", "KCNH2")) # red dropped
  expect_equal(gt$source_score_raw[gt$gene_symbol == "KCNQ1"], 1.0)
  expect_equal(gt$source_score_raw[gt$gene_symbol == "KCNH2"], 0.5)
})

test_that("fetch_panelapp() returns empty when no panel matches", {
  index_fn <- function(max_pages, page_size, ...) {
    biohttp::status_ok(
      tibble::tibble(
        id = 9L,
        name = "Cystic fibrosis",
        version = "1.0",
        disorders = list(list()),
        source_url = "https://p/9/"
      ),
      source = "PanelApp"
    )
  }
  expect_equal(
    nrow(fetch_panelapp(list(name = "zzz nomatch"), index_fn = index_fn)),
    0
  )
})

test_that("panelapp_collect_panels() asks for 8 pages, not bioclients' 6", {
  # bioclients defaults max_pages to 6 where this app has always used 8.
  # Relying on the default would silently shrink the searchable index and
  # could change which panel is selected.
  asked <- NULL
  index_fn <- function(max_pages, page_size, ...) {
    asked <<- max_pages
    biohttp::status_ok(tibble::tibble(), source = "PanelApp")
  }
  panelapp_collect_panels(index_fn)
  expect_equal(asked, 8)
})

test_that("fetch_diseases() takes the max score per gene across channels", {
  doid_fn <- function(efo, prefix) "DOID:1324"
  channel_fn <- function(doid, channel, ...) {
    if (channel == "Knowledge") {
      data.frame(
        gene_symbol = c("KRAS", "TP53"),
        score = c(5, 4),
        url = "u",
        stringsAsFactors = FALSE
      )
    } else {
      data.frame(
        gene_symbol = c("EGFR", "TP53"),
        score = c(4, 2),
        url = "u",
        stringsAsFactors = FALSE
      )
    }
  }
  gt <- fetch_diseases(
    list(id = "MONDO_1", name = "x"),
    doid_fn = doid_fn,
    channel_fn = channel_fn
  )
  expect_setequal(gt$gene_symbol, c("KRAS", "TP53", "EGFR"))
  expect_equal(gt$source_score_raw[gt$gene_symbol == "TP53"], 4) # max(4,2)
})

test_that("glb_diseases_channel() maps the bioclients columns", {
  # Regression test. The existing fetch_diseases tests inject channel_fn one
  # level ABOVE this, so they kept passing while this function was reading a
  # source_url column that diseases_channel() does not return. Only a live call
  # caught it. This asserts against the real column set.
  client_fn <- function(doid, channel, limit, ...) {
    biohttp::status_ok(
      tibble::tibble(
        symbol = c("KRAS", "TP53"),
        protein = c("ENSP1", "ENSP2"),
        score = c(5, 4),
        channel = channel
      ),
      source = "DISEASES"
    )
  }
  out <- glb_diseases_channel("DOID:1324", "Knowledge", client_fn = client_fn)
  expect_equal(out$gene_symbol, c("KRAS", "TP53"))
  expect_equal(out$score, c(5, 4))
  expect_true(all(grepl("DOID%3A1324", out$url)))
})

test_that("glb_diseases_channel() degrades to empty when the client fails", {
  failing <- function(doid, channel, limit, ...) {
    biohttp::status_error(source = "DISEASES")
  }
  expect_equal(
    nrow(glb_diseases_channel("DOID:1", "Knowledge", client_fn = failing)),
    0
  )
})

test_that("fetch_diseases() keeps one channel when the other fails", {
  # bioclients::diseases_gene_associations() would fail the whole source if
  # either channel failed. Fetching channels separately preserves the app's
  # graceful degradation, so curated results survive a Textmining outage.
  channel_fn <- function(doid, channel, ...) {
    if (channel == "Knowledge") {
      data.frame(
        gene_symbol = c("KRAS"),
        score = 5,
        url = "u",
        stringsAsFactors = FALSE
      )
    } else {
      data.frame()
    }
  }
  gt <- fetch_diseases(
    list(id = "MONDO_1", name = "x"),
    doid_fn = function(efo, prefix) "DOID:1324",
    channel_fn = channel_fn
  )
  expect_equal(gt$gene_symbol, "KRAS")
})

test_that("fetch_diseases() returns empty without a DOID", {
  doid_fn <- function(efo, prefix) NA_character_
  expect_equal(
    nrow(fetch_diseases(list(id = "X", name = "x"), doid_fn = doid_fn)),
    0
  )
})

test_that("fetch_clinvar() counts pathogenic records per gene", {
  esearch_fn <- function(term, retmax) c("1", "2", "3")
  esummary_fn <- function(ids) c("KCNH2", "KCNH2", "KCNQ1")
  gt <- fetch_clinvar(
    list(name = "long QT syndrome"),
    esearch_fn = esearch_fn,
    esummary_fn = esummary_fn
  )
  expect_equal(gt$source_score_raw[gt$gene_symbol == "KCNH2"], 2)
  expect_equal(gt$n_evidence[gt$gene_symbol == "KCNQ1"], 1L)
})

test_that("fetch_clinvar() returns empty when no records match", {
  expect_equal(
    nrow(fetch_clinvar(list(name = "x"), esearch_fn = function(...) {
      character()
    })),
    0
  )
})

test_that("fetch_gnomad() keeps genes with LOEUF and drops misses", {
  # bioclients returns one row per input symbol, with an all-NA row for a gene
  # gnomAD does not constrain. Those must be dropped, not scored as NA.
  client_fn <- function(symbols, ...) {
    biohttp::status_ok(
      tibble::tibble(
        symbol = c("TP53", "BRCA1", "FAKE"),
        pli = c(0.9, 0.8, NA_real_),
        loeuf = c(0.4, 0.9, NA_real_)
      ),
      source = "gnomAD"
    )
  }
  gt <- fetch_gnomad(
    gene_symbols = c("TP53", "BRCA1", "FAKE"),
    client_fn = client_fn
  )
  expect_setequal(gt$gene_symbol, c("TP53", "BRCA1"))
  expect_equal(gt$source_score_raw[gt$gene_symbol == "TP53"], 0.4)
})

test_that("fetch_gnomad() degrades to an empty table when the client fails", {
  failing <- function(symbols, ...) biohttp::status_timeout(source = "gnomAD")
  gt <- fetch_gnomad(gene_symbols = c("TP53"), client_fn = failing)
  expect_equal(nrow(gt), 0)
  expect_true(validate_gene_table(gt))
})

test_that("gnomad_known_symbols() drops symbols that would poison the batch", {
  # gnomAD aliases genes into one GraphQL query, and a single unresolvable
  # symbol nulls out the entire batch (verified live: c("TP53","ZZZNOTAGENE")
  # returns NA for BOTH). Filtering unknown symbols first protects the rest.
  expect_equal(
    gnomad_known_symbols(c("EGFR", "ZZZNOTAGENE", "TP53")),
    c("EGFR", "TP53")
  )
  expect_length(gnomad_known_symbols(character()), 0)
})

test_that("fetch_gnomad() filters unknown symbols before querying", {
  asked <- NULL
  client_fn <- function(symbols, ...) {
    asked <<- symbols
    biohttp::status_ok(
      tibble::tibble(symbol = symbols, loeuf = rep(0.5, length(symbols))),
      source = "gnomAD"
    )
  }
  fetch_gnomad(
    gene_symbols = c("TP53", "ZZZNOTAGENE", "BRAF"),
    client_fn = client_fn
  )
  expect_false("ZZZNOTAGENE" %in% asked)
  expect_setequal(asked, c("TP53", "BRAF"))
})

test_that("fetch_pharos() maps TDL tiers to scores", {
  # bioclients returns one row per INPUT symbol, with tdl NA both for unknown
  # symbols and for any level outside its allowed set. Those must be dropped.
  client_fn <- function(symbols, ...) {
    biohttp::status_ok(
      tibble::tibble(
        symbol = c("EGFR", "TP53", "DARKGENE", "UNKNOWN"),
        tdl = c("Tclin", "Tchem", "Tdark", NA_character_),
        source_url = rep("https://pharos.nih.gov/", 4)
      ),
      source = "Pharos"
    )
  }
  gt <- fetch_pharos(
    gene_symbols = c("EGFR", "TP53", "DARKGENE", "UNKNOWN"),
    client_fn = client_fn
  )
  expect_equal(gt$source_score_raw[gt$gene_symbol == "EGFR"], 1.0)
  expect_equal(gt$source_score_raw[gt$gene_symbol == "DARKGENE"], 0.25)
  expect_false("UNKNOWN" %in% gt$gene_symbol)
})

test_that("fetch_pharos() degrades to an empty table when the client fails", {
  # Pharos was returning HTTP 502 while this was written, so this path is not
  # hypothetical.
  failing <- function(symbols, ...) biohttp::status_error(source = "Pharos")
  gt <- fetch_pharos(gene_symbols = c("EGFR"), client_fn = failing)
  expect_equal(nrow(gt), 0)
  expect_true(validate_gene_table(gt))
})

test_that("annotation sources score but do not inflate coverage", {
  ot <- as_gene_table(
    data.frame(gene_symbol = c("TP53", "EGFR"), source_score_raw = c(0.9, 0.8)),
    "opentargets"
  )
  gn <- as_gene_table(
    data.frame(
      # PHANTOM is present only in the annotation source (e.g. an alias the
      # source canonicalized to a symbol no evidence source reported).
      gene_symbol = c("TP53", "EGFR", "PHANTOM"),
      source_score_raw = c(0.4, 0.9, 0.2)
    ),
    "gnomad"
  )
  agg <- aggregate_sources(
    list(opentargets = ot, gnomad = gn),
    norm_methods = c(opentargets = "passthrough", gnomad = "rank_desc"),
    evidence_ids = "opentargets"
  )
  expect_false("PHANTOM" %in% agg$gene_symbol) # annotation-only gene dropped
  expect_equal(agg$n_sources, c(1L, 1L)) # gnomad not counted
  expect_false(any(grepl("gnomad", agg$sources)))
  expect_true("score_gnomad" %in% names(agg))

  # rank_desc: lower LOEUF (TP53 0.4) -> higher constraint score.
  expect_gt(
    agg$score_gnomad[agg$gene_symbol == "TP53"],
    agg$score_gnomad[agg$gene_symbol == "EGFR"]
  )

  r <- rank_genes(agg, coverage_bonus = 0.5, evidence_ids = "opentargets")
  expect_true(all(r$combined_score > 0))
  expect_equal(r$gene_symbol[1], "TP53") # constraint nudges TP53 to the top
})

# --- PanelApp panel selection ------------------------------------------------
#
# Characterisation tests written BEFORE the bioclients refactor. Which panel
# gets picked determines the entire gene list for this source, and the matching
# heuristic (token overlap + strict majority) has no bioclients equivalent, so
# it must survive the migration byte for byte. These lock in the current
# behaviour so a change in panel choice cannot slip through unnoticed.

test_that("panelapp_tokens() drops short and generic words", {
  expect_setequal(panelapp_tokens("Inherited lung cancer"), c("lung", "cancer"))
  expect_setequal(panelapp_tokens("Long QT syndrome"), c("long"))
  expect_length(panelapp_tokens(""), 0)
  expect_length(panelapp_tokens(NULL), 0)
})

test_that("panelapp_best_panel() requires a strict majority of tokens", {
  panels <- list(
    list(name = "Familial breast cancer", relevant_disorders = list()),
    list(name = "Childhood solid tumours", relevant_disorders = list()),
    list(name = "Inherited lung cancer", relevant_disorders = list())
  )
  # "lung cancer" -> tokens lung, cancer; needs >= 2 matches.
  expect_equal(
    panelapp_best_panel(panels, "lung cancer")$name,
    "Inherited lung cancer"
  )

  # A panel sharing only the broad token "cancer" is NOT good enough.
  weak <- list(list(
    name = "Familial breast cancer",
    relevant_disorders = list()
  ))
  expect_null(panelapp_best_panel(weak, "lung cancer"))

  expect_null(panelapp_best_panel(list(), "lung cancer"))
  expect_null(panelapp_best_panel(panels, ""))
})

test_that("panelapp_best_panel() also matches on relevant_disorders", {
  panels <- list(
    list(name = "Panel A", relevant_disorders = list("Long QT")),
    list(name = "Panel B", relevant_disorders = list())
  )
  expect_equal(panelapp_best_panel(panels, "long QT")$name, "Panel A")
})
