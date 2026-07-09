# End-to-end smoke test: launch the real app in a headless browser, run the
# pipeline against the offline demo data (GLB_TEST_MODE), and confirm the ranked
# table renders. Skipped when shinytest2/Chrome is unavailable.

test_that("app boots and builds a gene list (offline demo mode)", {
  testthat::skip_if_not_installed("shinytest2")
  withr::local_envvar(GLB_TEST_MODE = "1")

  app <- tryCatch(
    shinytest2::AppDriver$new(
      app_dir = test_path("..", ".."),
      name = "builder-smoke",
      height = 900,
      width = 1300
    ),
    error = function(e) {
      testthat::skip(paste("could not launch app:", conditionMessage(e)))
    }
  )
  withr::defer(app$stop())

  app$set_inputs(`disease-term` = "lung cancer")
  app$click("disease-resolve")
  app$wait_for_idle()

  app$set_inputs(`disease-choice` = "MONDO_0008903")
  app$click("run-run")
  app$wait_for_idle(timeout = 20000)

  # Switch to the ranked tab and confirm a demo gene shows up.
  app$set_inputs(steps = "2. Ranked")
  app$wait_for_idle()
  html <- app$get_html("#results-tbl")
  expect_true(grepl("EGFR", html))
})
