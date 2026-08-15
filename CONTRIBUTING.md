# Contributing

Thanks for looking. This is a one-person project, so for anything large please
open an issue first: that way you get an early yes or no instead of sinking time
into work that may not land. Small fixes are welcome as a pull request straight
away.

Please also read the [Code of Conduct](CODE_OF_CONDUCT.md).

## Setup

```r
renv::restore()   # install the pinned dependencies
shiny::runApp()   # run the app
```

The git hooks are optional but recommended:

```bash
pip install prek
prek install
```

## Where code goes

- `R/` for pure logic: the schema, the source adapters, the ranking, the
  curator. `R/load_components.R` sources them for you.
- `modules/` for Shiny modules.
- `userInterface/` for the page layouts.
- `tests/testthat/` for the tests.

To add a gene-disease source, write one adapter that returns the canonical
schema and call `register_source()` in `R/source_registry.R`. Nothing in the
pipeline needs to change.

## Before you open a pull request

Branch from `main` and open the pull request against `main`. Then check that
all of this passes:

```bash
air format --check .      # format, configured in air.toml
```

```r
shiny::runTests(".")      # tests
shiny::runApp()           # the app still starts
```

Add a test for what you changed: a unit test for an `R/` helper, a
`shiny::testServer()` test for module reactivity, or a `shinytest2` test for
end-to-end behavior. Tests run without network access, so stub any new client.
If behavior changed, update the README too.

The `CI` workflow runs the same lint, format check, tests, and Markdown lint on
every push and pull request.
