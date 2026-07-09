test_that("app_version() returns the current version string", {
  expect_type(app_version(), "character")
  expect_match(app_version(), "^[0-9]+[.][0-9]+[.][0-9]+$")
})

test_that("safe_read_rds() returns the default for a missing file", {
  expect_null(safe_read_rds(tempfile()))
  expect_identical(safe_read_rds(tempfile(), default = "fallback"), "fallback")
})

test_that("safe_read_rds() reads an existing file", {
  path <- tempfile(fileext = ".rds")
  saveRDS(mtcars, path)
  on.exit(unlink(path), add = TRUE)

  expect_equal(safe_read_rds(path), mtcars)
})

test_that("clamp01() bounds to the unit interval", {
  expect_equal(clamp01(c(-1, 0.5, 2)), c(0, 0.5, 1))
  expect_true(is.na(clamp01(NA)))
})

test_that("normalize_rank() maps to (0, 1] with max-rank ties", {
  expect_equal(normalize_rank(c(10, 20, 30)), c(1, 2, 3) / 3)
  expect_equal(normalize_rank(c(1, 1, 1)), c(1, 1, 1))
  expect_equal(normalize_rank(c(5, 3)), c(1, 0.5))
  expect_true(all(is.na(normalize_rank(c(NA, NA)))))
})

test_that("truthy() recognizes common on values", {
  expect_true(truthy("1"))
  expect_true(truthy("TRUE"))
  expect_true(truthy("yes"))
  expect_false(truthy(""))
  expect_false(truthy("0"))
})
