# Load libraries and source files
library(shiny)
library(bslib)

# The loading spinner defaults to a saturated Bootstrap blue that clashes with
# the theme. Pull it to the bronze accent. Read from the compiled theme rather
# than hard-coded so _brand.yml stays the single source of truth for colour.
options(
  spinner.color = bslib::bs_get_variables(
    bslib::bs_theme(brand = TRUE),
    "primary"
  )[["primary"]]
)

source("R/load_components.R")

# Load data/connections
# Example: app_data <- readRDS("data/app_data.rds")

# Preprocess small data
