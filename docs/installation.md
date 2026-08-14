# Installation

## Install the dependencies

`biohttp`, `bioclients`, and `biobouncer` are not on CRAN. They are published to
an r-universe repo, which behaves like an ordinary CRAN mirror, so one call
installs everything:

```r
install.packages(
  c("shiny", "bslib", "brand.yml", "dplyr", "tibble", "tidyr", "rlang", "DT",
    "shinycssloaders", "ellmer", "shinyvalidate", "cicerone", "shinyjs",
    "biohttp", "bioclients", "biobouncer"),
  repos = c("https://samuelbharti.r-universe.dev", "https://cloud.r-project.org")
)
```

Then start the app with `shiny::runApp()`.

> **Note:** this project has no `renv.lock` yet. Earlier docs told you to run
> `renv::restore()`, which could never have worked. Adding a lockfile is
> worthwhile (it would pin the biobouncer version, which determines the bundled
> HGNC snapshot and therefore affects reproducibility of scores), but it has not
> been done. The Docker image already handles both cases.

### Quick-start helper

This template includes a helper script to initialize `renv` for a new project. Run:

```sh
Rscript dev/init-renv.R
```

This will create `renv.lock` after installing a small set of recommended packages. Review the lockfile before committing.

## Manual setup

Install required packages listed in README and run `shiny::runApp()`.

## Docker

Build:

```bash
docker build -t my-shiny-app .
```

Run:

```bash
docker run --rm -p 3838:3838 my-shiny-app
```

The Dockerfile is intended to restore from `renv.lock` rather than install packages ad hoc.
