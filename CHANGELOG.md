# Changelog

All notable changes to this project should be documented in this file.

## [Unreleased]

## [0.2.1] - 2026-08-15

### Fixed

- `renv.lock` and `manifest.json` recorded `biobouncer`, `biohttp` and
  `bioclients` with the R-universe URL as their repository. Connect Cloud
  installs from CRAN and Bioconductor and cannot read that, so deployment
  stopped with "installation of biobouncer failed". All three now record the
  public GitHub source, pinned to the commit of the newest R-universe build.
- `manifest.json` did not name `brand.yml`. bslib lists it under Suggests, so
  Connect Cloud never installed it and `bs_theme(brand = TRUE)` failed at
  startup. It is now named explicitly.
- The Zenodo DOI badge did not render. GitHub proxies README images through
  camo, and Zenodo answers camo with a 429. It is now a shields.io badge with
  the same DOI and link target.

### Changed

- Shortened the Code of Conduct, which still carried the `[INSERT CONTACT
  METHOD]` placeholder, and rewrote the contributing guide.
- Added a security policy, and an Author section to the README.

## [0.2.0] - 2026-08-14

- Built the core pipeline: disease-to-ontology resolution (Open Targets),
  multi-source gene-disease association queries, aggregation/dedup into a
  common schema, transparent source-weighted ranking, and CSV/Markdown
  export.
- Added Open Targets, PanelApp, DISEASES, ClinVar, and DGIdb as evidence
  sources, and gnomAD and Pharos as annotation (prioritizing) sources,
  through an extensible source registry.
- Added optional AI curation via Google Gemini (BYOK), falling back to
  top-N-by-rank when no key is set.
- Migrated every source adapter onto `biohttp`/`bioclients`, replacing ad hoc
  HTTP calls with shared transport, caching, and honest per-source status
  reporting instead of a single boolean `ok`.
- Added corroborated alias merging (`GLB_REPAIR_SYMBOLS`) and microRNA
  labelling via `biobouncer`'s bundled HGNC snapshot, exposed as a
  `symbol_status` diagnostic column.
- Added `renv.lock`, pinning all dependencies including the exact
  `biobouncer` version (its bundled HGNC snapshot determines results).
- Rethemed the UI, settling on "Cream & Crimson" with a unified navbar,
  compact footer, and wider sidebar; added a cicerone guided demo tour and a
  BYOK AI assistant chat module.
- Added gitleaks secret scanning to the pre-commit hooks.
- Added Posit Connect Cloud deployment support (`manifest.json`,
  `.rscignore`).

## [2.2.0] - 2026-06-29

- Added GitHub Actions CI (lint, air format check, tests, markdownlint) and
  pre-commit hooks.
- Added air formatter and lintr configuration.
- Added a test suite (testthat unit tests, `testServer`, and a shinytest2
  smoke test).
- Added brand.yml theming applied through bslib, with optional `thematic`
  plot/table theming.
- Added a template manifest (`template.yml`) and `dev/use_template.R`
  scaffolding engine; published the repo as a GitHub template.
- Added issue and pull request templates and a Contributor Covenant code of
  conduct.
- Fixed the app entry point and ensured `R/` utilities are sourced at startup.

## [0.1.0] - 2026-05-01

- Created base Shiny template structure.

## [2.0.0] - 2026-05-02

- Bumped template version to v2.0 and updated metadata (CITATION, README).
