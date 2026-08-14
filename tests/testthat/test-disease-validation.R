# Inline validation of the disease box.
#
# The rule must FAIL OPEN. The input is deliberately free text ("lung cancer"
# or a pasted ontology id), so a rule that rejects anything it does not
# recognise would make the app unusable. It may only reject a string that looks
# like an ontology id of a known prefix but is malformed.

test_that("free text is always accepted", {
  expect_null(glb_disease_id_rule("lung cancer"))
  expect_null(glb_disease_id_rule("breast carcinoma"))
  expect_null(glb_disease_id_rule("  "))
  expect_null(glb_disease_id_rule(""))
  expect_null(glb_disease_id_rule(NULL))
})

test_that("well-formed ontology ids are accepted in both forms", {
  # The app accepts underscore and colon interchangeably; biobouncer's
  # patterns only accept the colon form, so the rule must normalise first.
  expect_null(glb_disease_id_rule("MONDO:0008903"))
  expect_null(glb_disease_id_rule("MONDO_0008903"))
  expect_null(glb_disease_id_rule("EFO_0000305"))
  expect_null(glb_disease_id_rule("EFO:0000305"))
  expect_null(glb_disease_id_rule("HP:0100526"))
  expect_null(glb_disease_id_rule("DOID:1324"))
})

test_that("prefixes biobouncer disagrees with are passed through, not rejected", {
  # Orphanet and OTAR are accepted by DISEASE_ID_RX and handled by the
  # resolver, but biobouncer either expects a different form or has no source
  # for them. Rejecting these would be a false negative.
  expect_null(glb_disease_id_rule("Orphanet:158673"))
  expect_null(glb_disease_id_rule("ORPHA:158673"))
  expect_null(glb_disease_id_rule("OTAR:0000018"))
})

test_that("a malformed id of a known prefix is rejected", {
  expect_type(glb_disease_id_rule("MONDO:99"), "character")
  expect_type(glb_disease_id_rule("MONDO_XXXX"), "character")
  expect_match(glb_disease_id_rule("MONDO:99"), "MONDO")
})

test_that("every mapped prefix is a real biobouncer source", {
  skip_if_not_installed("biobouncer")
  expect_true(all(GLB_ID_SOURCES %in% biobouncer::sources()))
})
