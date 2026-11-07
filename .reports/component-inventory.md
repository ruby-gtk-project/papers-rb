# papers-rb component inventory

Surveyed against upstream `origin/main` (the GNOME Papers Rust/C shell and
libview, ~752 tracked files) vs. the `ruby` branch's `lib/` (29 files). This
is the opening survey of a fresh fork: the point is the map of how much is
left, not a widget-by-widget breakdown of any one unit (see
`component-identification`). Each row is one upstream component file (or the
`.c`/`.h` + `.blp` pair that is one component upstream), the `lib/*.rb` path
it should become, its kind, and whether that port file exists today.

Legend for **kind**: `window`, `dialog`, `page` (sidebar/stack page),
`row` (list row widget), `widget` (other on-screen widget), `menu`,
`shortcuts`, `model` (non-widget context/data object), `app` (application
class), `settings`/`schema`.

## Application shell (`shell/src/`, `shell/resources/*.blp`)

| Upstream file(s) | → `lib/` path | Kind | Exists? |
|---|---|---|---|
| `shell/src/main.rs` | `lib/papers.rb` (require entrypoint) + `exe/papers` | app | **yes** |
| `shell/src/application.rs` | `lib/papers/application.rb` | app | **yes** (app-level actions/accels/stylesheet only — see note below) |
| `shell/src/window.rs` + `shell/resources/pps-window.blp` (1341 lines; main menu `app_menu`, toolbar, `Adw.ViewStack` of loader/password/document views) | `lib/window.rb` | **window** | **MISSING** — the main `PpsWindow`. Nothing in `lib/` builds the app's actual window; `Application` only owns app-level chrome (its own header comment says so). This is the single largest gap. |
| `shell/src/document_view.rs` + `document_view/{actions,enums,io,print,signals}.rs` + `shell/resources/pps-document-view.blp` (971 lines core + 4 helper files) | `lib/document_view.rb` | widget (page) | **MISSING** |
| `shell/src/loader_view.rs` + `shell/resources/pps-loader-view.blp` | `lib/loader_view.rb` | page | **yes** |
| `shell/src/password_view.rs` + `shell/resources/pps-password-view.blp` | `lib/password_view.rb` | page | **yes** |
| `shell/src/sidebar.rs` + `shell/resources/pps-sidebar.blp` (196 lines; the sidebar's own `Adw.ViewStack`/switcher) | `lib/sidebar.rb` | widget | **MISSING** (`lib/sidebar_page.rb` only ports the *base class* each sidebar page subclasses, not the container) |
| `shell/src/sidebar_page.rs` | `lib/sidebar_page.rb` | model/base | **yes** |
| `shell/src/sidebar_thumbnails.rs` + `shell/resources/pps-sidebar-thumbnails.blp` (554 lines) | `lib/sidebar_thumbnails.rb` | page | **MISSING** (`lib/thumbnail_item.rb` ports the row, not the sidebar page that hosts the `Gtk.GridView`/`Gtk.ListView`) |
| `shell/src/thumbnail_item.rs` | `lib/thumbnail_item.rb` | row | **yes** |
| `shell/src/sidebar_links.rs` + `shell/resources/pps-sidebar-links.blp` (1000 lines — outline/TOC tree) | `lib/sidebar_links.rb` | page | **MISSING** |
| `shell/src/sidebar_attachments.rs` + `shell/resources/pps-sidebar-attachments.blp` (346 lines) | `lib/sidebar_attachments.rb` | page | **MISSING** |
| `shell/src/sidebar_layers.rs` + `shell/resources/pps-sidebar-layers.blp` (289 lines) | `lib/sidebar_layers.rb` | page | **MISSING** |
| `shell/src/sidebar_annotations.rs` + `shell/resources/pps-sidebar-annotations.blp` (205 lines) | `lib/sidebar_annotations.rb` | page | **MISSING** |
| `shell/src/sidebar_annotations_row.rs` + `shell/resources/pps-sidebar-annotations-row.blp` (291 lines) | `lib/sidebar_annotations_row.rb` | row | **MISSING** |
| `shell/src/find_sidebar.rs` + `shell/resources/pps-find-sidebar.blp` (292 lines — search results list) | `lib/find_sidebar.rb` | page | **MISSING** |
| `shell/src/search_box.rs` + `shell/resources/pps-search-box.blp` (262 lines — the header-bar find entry) | `lib/search_box.rb` | widget | **MISSING** |
| `shell/src/page_selector.rs` + `shell/resources/pps-page-selector.blp` (309 lines) | `lib/page_selector.rb` | widget | **MISSING** |
| `shell/src/properties_window.rs` + `shell/resources/pps-properties-window.blp` (143 lines — the tabbed `AdwDialog`) | `lib/properties_window.rb` | dialog | **MISSING** |
| `shell/src/properties_general.rs` (396 lines, no separate `.blp`: general-info tab) | `lib/properties_general.rb` | page | **MISSING** |
| `shell/src/properties_fonts.rs` + `shell/resources/pps-properties-fonts.blp` (129 lines) | `lib/properties_fonts.rb` | page | **MISSING** |
| `shell/src/properties_license.rs` + `shell/resources/pps-properties-license.blp` | `lib/properties_license.rb` | page | **yes** |
| `shell/src/properties_signatures.rs` + `shell/resources/pps-properties-signatures.blp` (407 lines) | `lib/properties_signatures.rb` | page | **MISSING** |
| `shell/src/annotation_properties_dialog.rs` + `shell/resources/pps-annotation-properties-dialog.blp` (176 lines) | `lib/annotation_properties_dialog.rb` | dialog | **MISSING** |
| `shell/src/sign_manually_dialog.rs` + `shell/resources/pps-sign-manually-dialog.blp` (426 lines) | `lib/sign_manually_dialog.rb` | dialog | **MISSING** |
| `shell/src/visual_signature_chooser.rs` + `shell/resources/pps-visual-signature-chooser.blp` (449 lines) | `lib/visual_signature_chooser.rb` | dialog | **MISSING** |
| `shell/src/signature_drawing_widget.rs` + `shell/resources/pps-signature-drawing-widget.blp` (806 lines — the freehand signature canvas) | `lib/signature_drawing_widget.rb` | widget | **MISSING** |
| `shell/src/signature_image_processing.rs` | `lib/signature_image_processing.rb` | model | **yes** |
| `shell/src/signature_manager.rs` | `lib/signature_manager.rb` | model | **yes** |
| `shell/src/simple_color_swatch.rs` | `lib/simple_color_swatch.rb` | widget | **yes** |
| `shell/src/password_dialog.rs`*¹* + `shell/resources/pps-password-dialog.blp` | `lib/password_dialog.rb` | dialog | **yes** |
| `shell/src/shortcuts_dialog.rs`*¹* + `shell/resources/pps-shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | shortcuts | **yes** |
| `shell/src/file_monitor.rs` | `lib/file_monitor.rb` | model | **yes** |
| `shell/src/ink_transformation.rs` | `lib/ink_transformation.rb` | model | **yes** |
| `shell/src/keyring.rs` | `lib/keyring.rb` | model | **yes** |
| `shell/src/progress_message_area.rs` + `shell/resources/pps-progress-message-area.blp` | `lib/progress_message_area.rb` | widget | **yes** |
| `shell/src/deps.rs` | — | internal (crate plumbing, no port equivalent needed) | n/a |

*¹ `password_dialog.rs` and `shortcuts_dialog.rs` are not in the `shell/src/` listing from the TSV scan above but their `.blp`s are ported in `lib/`; the `.rs` logic lives inline in `window.rs`/`application.rs` upstream — flag this when `window.rb` is built, since porting the window will need to re-derive their call sites.*

## libview (`libview/*.c` + `.blp` — the document-rendering engine and its overlays)

| Upstream file(s) | → `lib/` path | Kind | Exists? |
|---|---|---|---|
| `libview/pps-view.c/.h` + `libview/pps-view.blp` (7745 lines — the core scrollable page view) | `lib/view.rb` | widget | **MISSING** — largest single upstream file, not ported at all |
| `libview/pps-view-presentation.c/.h` + `libview/pps-view-presentation.blp` (1571 lines — fullscreen presentation mode) | `lib/view_presentation.rb` | widget | **MISSING** |
| `libview/pps-view-page.c/.h` (1615 lines — one rendered page) | `lib/view_page.rb` | widget | **MISSING** |
| `libview/pps-view-cursor.c/.h` | `lib/view_cursor.rb` | model | **yes** |
| `libview/pps-colors.c/.h` | `lib/view_colors.rb` | model | **yes** |
| `libview/pps-css-utils.c/.h` | `lib/css_utils.rb` | model | **yes** |
| `libview/pps-annotation-layer.c/.h` (172 lines, dispatch base) | `lib/annotation_layer.rb` | widget | **MISSING** |
| `libview/pps-annotation-layer-ink.c/.h` (906 lines) | `lib/annotation_layer_ink.rb` | widget | **MISSING** |
| `libview/pps-annotation-layer-objects.c/.h` (85 lines) | `lib/annotation_layer_objects.rb` | widget | **MISSING** |
| `libview/pps-annotation-overlay.c/.h` (1059 lines) | `lib/annotation_overlay.rb` | widget | **MISSING** |
| `libview/pps-annotation-window.c/.h` (408 lines — the popover shown on an annotation) | `lib/annotation_window.rb` | widget | **yes** (file exists; confirm it covers this, not just the annotation-tool popover — re-check against this 408-line source when revisited) |
| `libview/pps-form-overlay.c/.h` (695 lines — interactive form-field widgets drawn over the page) | `lib/form_overlay.rb` | widget | **MISSING** |
| `libview/pps-overlay.c/.h` (47 lines, shared base) | `lib/overlay.rb` | widget | **MISSING** |
| `libview/pps-print-operation.c/.h` (2083 lines) | `lib/print_operation.rb` | model | **MISSING** |
| `libview/pps-page-cache.c/.h`, `pps-pixbuf-cache.c/.h`, `pps-job*.c/.h` | `lib/page_cache.rb`, `lib/pixbuf_cache.rb`, `lib/job*.rb` | model (rendering/scheduling internals) | **MISSING** — needed once `view.rb` is built; not independently user-facing |
| `libview/factory/pps-annotation-widget-factory.c/.h`, `pps-element-widget-factory.c/.h`, `pps-form-widget-factory.c/.h` | `lib/*_widget_factory.rb` | factory (produces widgets) | **MISSING** |
| `libview/context/pps-annotation-model.c/.h` | `lib/annotation_model.rb` | model | **yes** |
| `libview/context/pps-annotations-context.c/.h` | `lib/annotations_context.rb` | model | **MISSING** (distinct from `annotation_model.rb`, which already exists) |
| `libview/context/pps-attachment-context.c/.h` | `lib/attachment_context.rb` | model | **MISSING** |
| `libview/context/pps-document-model.c/.h` | `lib/document_model.rb` | model | **yes** |
| `libview/context/pps-history.c/.h` | `lib/history.rb` | model | **yes** |
| `libview/context/pps-metadata.c/.h` | `lib/metadata.rb` | model | **yes** |
| `libview/context/pps-search-context.c/.h` | `lib/search_context.rb` | model | **MISSING** (distinct from `search_result.rb`, which already exists) |
| `libview/context/pps-search-result.c/.h` | `lib/search_result.rb` | model | **yes** |
| `libview/context/pps-undo-context.c/.h` | `lib/undo_context.rb` | model | **yes** |
| `libview/context/pps-undo-handler.c/.h` | `lib/undo_handler.rb` | model | **yes** |

## Previewer (separate binary, `previewer/`)

Out of scope for `papers` proper but a real user-facing surface (the
`gtk4-print`/CUPS print-preview helper). Entirely unported:

| Upstream file(s) | → `lib/` path | Kind | Exists? |
|---|---|---|---|
| `previewer/pps-previewer.c` (302 lines, entrypoint) | `lib/previewer.rb` or `exe/papers-previewer` | app | **MISSING** |
| `previewer/pps-previewer-window.c/.h` + `.blp` (616 lines) | `lib/previewer_window.rb` | window | **MISSING** |
| `previewer/pps-page-selector.c/.h` + `.blp` (324 lines) | `lib/previewer_page_selector.rb` | widget | **MISSING** |

## Thumbnailer (separate binary, `thumbnailer/`)

| Upstream file | → `lib/` path | Kind | Exists? |
|---|---|---|---|
| `thumbnailer/src/main.rs` | `exe/papers-thumbnailer` or `lib/thumbnailer.rb` | app (headless, no widgets) | **MISSING** |

## GSettings schema, menus, keyboard shortcuts

| Upstream file | Port equivalent | Exists? |
|---|---|---|
| `data/org.gnome.Papers.gschema.xml` (31 keys) | `lib/settings.rb` | **yes** |
| `shell/resources/pps-window.blp` `menu app_menu { … }` (primary menu: new window, help, about/shortcuts/quit — 3 `item`s read off the scan) | part of `lib/window.rb` | **MISSING** (menu lives in the unported window) |
| `shell/resources/pps-shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | **yes** |
| `po/` (107 tracked files: `LINGUAS`, `POTFILES.in/.skip`, ~104 `.po` catalogues) | no `po/` directory on `ruby` yet | **MISSING** — translation-parity is a separate skill/pass, flagged here for completeness only |

## Gem wiring check (per task instructions)

`libspelling` (`Spelling` namespace) is declared in the gemspec and the
flake's `gtkStack`, and is `require`d and called from
`lib/annotation_window.rb` (used from
`Papers::Application#open_annotation_window` per that file's own header
comment). This was not re-verified live in this survey pass (no app code was
run — this step is survey-only per the task), but the static wiring
(gemspec dependency, flake typelib, `require` + call site) is intact and
nothing in `lib/` hand-rolls spell-checking in its place. No regression
found; no action taken.

## Summary

- `lib/` currently ports **21 of the ~60 user-facing/model components**
  identified above (the context/model layer almost entirely, plus five small
  dialogs/pages: loader view, password view, password dialog, shortcuts
  dialog, properties-license page, progress message area, and three small
  widgets).
- The entire **window chrome** (`PpsWindow`), the **document view** stack
  page, the **core rendering widget** (`PpsView`, `PpsViewPage`,
  `PpsViewPresentation`), every **sidebar page** except the thumbnails row
  widget, the **properties dialog**'s general/fonts/signatures tabs, and all
  **signature-related dialogs/widgets** (sign-manually, visual-signature
  chooser, signature drawing canvas) are unported. These are the largest and
  most central components in the app — `window.rb` and `view.rb` should be
  the next components built, since nearly everything else nests inside them.
- The **previewer** and **thumbnailer** are separate binaries, fully
  unported; lower priority than the main app surface.
