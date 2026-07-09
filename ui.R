navbarPage(
  title = "Gene List Builder",
  # Apply branding from _brand.yml (colors, fonts).
  theme = bslib::bs_theme(brand = TRUE),
  tabPanel("Build", builder_page),
  tabPanel("About", about_page)
)
