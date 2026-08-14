# --- Theme: "Bone & Bronze" minimal light Sass pass ---------------------------
# The palette lives in _brand.yml and reaches this Sass as `$brand-<name>`
# variables, so there are NO literal hex codes below. Adding a colour means
# adding a palette entry there, not a hex here.
#
# The look: warm bone canvas, near-white cards with hairline borders for
# hierarchy (so the page doesn't read as one flat colour), a clean bordered
# navbar, gently rounded controls, and a slim themed scrollbar.
.glb_theme <- bslib::bs_add_rules(
  bslib::bs_theme(brand = TRUE),
  "
  /* Bone canvas so the near-white cards read as intentional raised surfaces
     (the standard dashboard pattern) rather than boxes floating on the same
     colour. $brand-canvas is also the Bootstrap $body-bg via _brand.yml. */

  /* Cards + hairline border + a whisper of shadow = clear hierarchy without
     heavy colour. The shadow tints from the ink so it stays warm. */
  .card {
    background-color: $brand-card;
    border: 1px solid $brand-border;
    border-radius: 0.6rem;
    box-shadow: 0 1px 2px rgba($brand-ink, 0.05);
  }
  .card-header {
    background-color: $brand-card;
    border-bottom: 1px solid $brand-border;
    font-weight: 600;
  }
  /* Value boxes: bslib fills the whole box with the semantic colour, which at
     this size reads as three heavy slabs of colour. Keep them on the card
     surface and carry the status in a coloured left edge instead, so status
     stays legible without the page shouting. Written per semantic class so it
     survives whatever status -> theme mapping the status module uses. */
  .bslib-value-box { border-radius: 0.6rem; }
  .bslib-value-box[class*='bg-'] {
    background-color: $brand-card !important;
    color: $brand-ink !important;
    border: 1px solid $brand-border;
    box-shadow: 0 1px 2px rgba($brand-ink, 0.05);
  }
  .bslib-value-box[class*='bg-'] .value-box-title {
    color: $brand-muted !important;
  }
  .bslib-value-box[class*='bg-'] { border-left-width: 4px !important; }
  .bslib-value-box.bg-success { border-left-color: $brand-green !important; }
  .bslib-value-box.bg-danger { border-left-color: $brand-red !important; }
  .bslib-value-box.bg-warning { border-left-color: $brand-amber !important; }
  .bslib-value-box.bg-secondary { border-left-color: $brand-muted !important; }
  .bslib-value-box.bg-primary { border-left-color: $brand-bronze !important; }

  /* Gently rounded, tactile controls. */
  .btn { border-radius: 0.5rem; }
  .form-control, .form-select, .selectize-input { border-radius: 0.5rem; }

  /* A filled muted-grey button reads as drab mud next to the bronze primary.
     Render secondary buttons as a quiet outline so the bronze stays the only
     filled accent on the page. */
  .btn-secondary {
    background-color: transparent;
    border-color: $brand-border;
    color: $brand-ink;
  }
  .btn-secondary:hover, .btn-secondary:focus, .btn-secondary:active {
    background-color: $brand-canvas;
    border-color: $brand-bronze;
    color: $brand-ink;
  }

  /* Clean navbar with a hairline base; ink text, bronze on hover/active. */
  .navbar {
    background-color: $brand-card !important;
    border-bottom: 1px solid $brand-border;
    box-shadow: none;
  }
  .navbar .navbar-brand, .navbar .nav-link { color: $brand-ink !important; }
  .navbar .nav-link:hover,
  .navbar .nav-link.active { color: $brand-bronze !important; }
  #demo_tour { border-radius: 2rem; font-weight: 600; }

  /* Slim, themed scrollbars (the default white track looked jarring on the
     warm ground). */
  * { scrollbar-width: thin; scrollbar-color: $brand-border transparent; }
  ::-webkit-scrollbar { width: 10px; height: 10px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb {
    background-color: darken($brand-border, 8%);
    border-radius: 8px;
    border: 2px solid $brand-canvas;
  }
  ::-webkit-scrollbar-thumb:hover { background-color: darken($brand-border, 20%); }

  /* Guided tour (cicerone/driver.js) ships its own stock skin, which clashes
     with the palette. Pull the popover and highlight ring into the theme. */
  .driver-popover {
    background-color: $brand-card;
    color: $brand-ink;
    border: 1px solid $brand-border;
    border-radius: 0.6rem;
    box-shadow: 0 4px 14px rgba($brand-ink, 0.12);
    font-family: inherit;
  }
  .driver-popover-title { color: $brand-ink; font-weight: 600; }
  .driver-popover-description { color: $brand-muted; }
  .driver-popover-progress-text { color: $brand-muted; }
  .driver-popover-arrow-side-top.driver-popover-arrow { border-top-color: $brand-card; }
  .driver-popover-arrow-side-bottom.driver-popover-arrow { border-bottom-color: $brand-card; }
  .driver-popover-arrow-side-left.driver-popover-arrow { border-left-color: $brand-card; }
  .driver-popover-arrow-side-right.driver-popover-arrow { border-right-color: $brand-card; }
  .driver-popover-navigation-btns button {
    background-color: $brand-bronze;
    color: $brand-card;
    border: none;
    border-radius: 0.5rem;
    text-shadow: none;
    font-weight: 500;
  }
  .driver-popover-navigation-btns button:hover {
    background-color: darken($brand-bronze, 8%);
  }
  .driver-popover-close-btn { color: $brand-muted; }

  /* DT ships an unbranded skin; theme its controls so paging and the
     copy/CSV buttons match the rest of the app. */
  .dataTables_wrapper .dataTables_paginate .paginate_button.current,
  .dataTables_wrapper .dataTables_paginate .paginate_button.current:hover {
    background: $brand-bronze !important;
    border-color: $brand-bronze !important;
    color: $brand-card !important;
  }
  .dataTables_wrapper .dataTables_paginate .paginate_button:hover {
    background: $brand-border !important;
    border-color: $brand-border !important;
    color: $brand-ink !important;
  }
  /* DT's Buttons extension inherits btn-secondary, which rendered as one dark
     slab. Force the quiet outline treatment used elsewhere. */
  .dt-buttons .dt-button,
  .dataTables_wrapper .dt-button,
  .dt-button.btn-secondary {
    background: $brand-card !important;
    background-image: none !important;
    border: 1px solid $brand-border !important;
    border-radius: 0.5rem !important;
    color: $brand-ink !important;
    margin-right: 0.35rem;
  }
  .dt-buttons .dt-button:hover,
  .dataTables_wrapper .dt-button:hover {
    background: $brand-canvas !important;
    border-color: $brand-bronze !important;
  }
  table.dataTable tbody tr { background-color: $brand-card; }
  table.dataTable.stripe tbody tr.odd,
  table.dataTable.display tbody tr.odd { background-color: $brand-canvas; }
  table.dataTable thead th { border-bottom: 1px solid $brand-border; }

  /* Consistent horizontal gutter on each page's content (not the navbar). */
  .bslib-page-navbar > .container-fluid > .tab-content > .tab-pane {
    padding-left: 4vw;
    padding-right: 4vw;
  }

  /* Tighten the build sidebar: no title, minimal top padding, so the Disease
     input sits near the top instead of below a big empty gap. */
  .glb-build-sidebar > .sidebar-content { padding-top: 0.5rem !important; }
  .glb-build-sidebar > .sidebar-content > div:first-child { margin-top: 0; }
  "
)

bslib::page_navbar(
  id = "main_nav",
  title = "Gene List Builder",
  # Branding from _brand.yml + the clean minimal Sass pass above.
  theme = .glb_theme,
  # Load shinyjs (demo auto-clicks the Resolve button) and cicerone (guided
  # tour) JS/CSS once for the whole app.
  header = tagList(
    shinyjs::useShinyjs(),
    cicerone::use_cicerone(),
    # Let the server click a control by DOM id (used by the assistant's tools to
    # drive Resolve / Build, and reused generally). Fire-and-forget from any
    # context via session$sendCustomMessage("glb_click", "<id>").
    tags$script(HTML(
      "Shiny.addCustomMessageHandler('glb_click', function(id){",
      "var el=document.getElementById(id); if(el){el.click();}});"
    ))
  ),
  # App-wide "Gene List Builder assistant": the chat lives in a left-hand
  # sidebar available on every page. It starts CLOSED so it never blocks the
  # workflow; users open it from the "Assistant" button in the navbar (which
  # toggles it client-side). Its model / key controls sit in a collapsed
  # section inside the dock (byok_chat_ui).
  sidebar = bslib::sidebar(
    id = "assistant_dock",
    title = tagList(shiny::icon("robot"), " Assistant"),
    position = "left",
    open = "closed",
    width = 600,
    byok_chat_ui(
      "chat",
      title = NULL,
      greeting = glb_chat_greeting,
      height = "calc(100vh - 190px)"
    )
  ),
  bslib::nav_panel("Build", builder_page),
  bslib::nav_panel("About", about_page),
  # Right-aligned navbar actions (nav_spacer pushes what follows to the right):
  # an assistant toggle (opens/closes the chat sidebar via server.R) and a
  # guided-demo launcher that prefills breast cancer and starts the tour.
  bslib::nav_spacer(),
  bslib::nav_item(
    # Toggle the assistant sidebar CLIENT-SIDE by clicking its built-in
    # collapse-toggle. A server-side sidebar_toggle would queue behind a running
    # build (Shiny is single-threaded), so the panel would appear frozen; this
    # opens instantly regardless of what the server is doing.
    actionButton(
      "toggle_assistant",
      "Assistant",
      icon = icon("comments"),
      class = "btn-sm btn-outline-primary my-1",
      onclick = paste0(
        "document.querySelector(",
        "\"button.collapse-toggle[aria-controls='assistant_dock']\"",
        ")?.click()"
      )
    )
  ),
  bslib::nav_item(
    actionButton(
      "demo_tour",
      "Demo",
      icon = icon("circle-play"),
      class = "btn-sm btn-primary my-1"
    )
  )
)
