# Tests for the additional source adapters, with all network calls injected.

test_that("fetch_panelapp() matches a panel and maps confidence, dropping red", {
  get_fn <- function(url) {
    if (grepl("panels/\\?", url)) {
      list(
        results = list(
          list(
            id = 1,
            name = "Long QT syndrome",
            relevant_disorders = list("R1")
          ),
          list(id = 2, name = "Cystic fibrosis", relevant_disorders = list())
        ),
        `next` = NULL
      )
    } else if (grepl("panels/1/", url)) {
      list(
        genes = list(
          list(entity_name = "KCNQ1", confidence_level = "3"),
          list(entity_name = "KCNH2", confidence_level = "2"),
          list(entity_name = "LOWCONF", confidence_level = "1")
        )
      )
    } else {
      NULL
    }
  }
  gt <- fetch_panelapp(list(name = "long QT syndrome"), get_fn = get_fn)
  expect_setequal(gt$gene_symbol, c("KCNQ1", "KCNH2")) # red dropped
  expect_equal(gt$source_score_raw[gt$gene_symbol == "KCNQ1"], 1.0)
  expect_equal(gt$source_score_raw[gt$gene_symbol == "KCNH2"], 0.5)
})

test_that("fetch_panelapp() returns empty when no panel matches", {
  get_fn <- function(url) {
    list(
      results = list(
        list(id = 9, name = "Cystic fibrosis", relevant_disorders = list())
      ),
      `next` = NULL
    )
  }
  expect_equal(
    nrow(fetch_panelapp(list(name = "zzz nomatch"), get_fn = get_fn)),
    0
  )
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
  graphql_fn <- function(query, variables) {
    list(
      targets = list(
        targets = list(
          list(sym = "EGFR", tdl = "Tclin"),
          list(sym = "TP53", tdl = "Tchem"),
          list(sym = "DARKGENE", tdl = "Tdark")
        )
      )
    )
  }
  gt <- fetch_pharos(
    gene_symbols = c("EGFR", "TP53", "DARKGENE"),
    graphql_fn = graphql_fn
  )
  expect_equal(gt$source_score_raw[gt$gene_symbol == "EGFR"], 1.0)
  expect_equal(gt$source_score_raw[gt$gene_symbol == "DARKGENE"], 0.25)
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
