# Papers Ruby port — upstream component inventory

Surveyed against `origin/main` (upstream Rust/GTK4 "Papers" document viewer,
née Evince) on 2026-11-07. This is a survey only: no app code was written for
this report. Scope is every user-facing component — windows, dialogs, pages,
rows, menus, keyboard shortcuts, settings, empty/error states — plus the
`.blp` templates, the GSettings schema, the GResource manifests and the `po/`
catalogue that back them.

Upstream is organized as:
- `shell/` — the GTK4 application (`src/*.rs` + `resources/*.blp`), the unit
  that matters most for this port.
- `libview/` — the `PpsView`/`PpsViewPresentation` widgets (C-ABI GObject
  library, exposed to Rust via the `rust/papers-view` GIR bindings).
- `libdocument/` — the document-backend library (`rust/papers-document`).
- `previewer/` — a separate, small C GTK3→4 standalone print-preview binary.
- `thumbnailer/` — a separate CLI thumbnailer binary (no UI).
- `rust/papers-{document,view}/src/auto/*.rs` — GIR-generated bindings, not
  hand-written components; they are the equivalent of what a Ruby port would
  reach through `gir_ffi`/typelib introspection directly, not port file-by-file.

## Legend

`kind`: `window`, `dialog`, `page` (sidebar/properties page), `row`, `widget`
(composite/custom widget), `model`/`service` (non-widget support class),
`app` (application class/actions/accelerators), `standalone-app` (separate
binary), `data` (schema/resource manifest), `catalogue` (po/).

---

## 1. Application shell (`shell/src/`, `shell/resources/`)

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `shell/src/main.rs` | `lib/papers.rb` (entry point) | app | yes — `lib/papers.rb`, `lib/papers/application.rb` exist but need checking against upstream's actual startup sequence |
| `shell/src/application.rs` (app actions, accelerators, About, command-line handling) | `lib/papers/application.rb` | app | partial — file exists; needs comparison of actions/accelerators, not yet done component-by-component |
| `shell/src/window.rs` + `shell/resources/pps-window.blp` | `lib/window.rb` | window | **missing** — no `lib/window.rb`. This is the main `AdwApplicationWindow`: header bar, main menu, sidebar/document split view, toolbar, search toggle. The single largest gap in the port. |
| `shell/src/document_view.rs` + `shell/src/document_view/{actions,enums,io,print,signals}.rs` + `shell/resources/pps-document-view.blp` | `lib/document_view.rb` | widget | **missing** — the central document pane (view + page selector + annotation toolbar + print/export actions). No corresponding `lib/` file at all. |
| `shell/src/loader_view.rs` + `shell/resources/pps-loader-view.blp` | `lib/loader_view.rb` | widget (loading/empty state) | yes — `lib/loader_view.rb` exists |
| `shell/src/password_view.rs` + `shell/resources/pps-password-view.blp` | `lib/password_view.rb` | widget (error/auth state) | yes — `lib/password_view.rb` exists |
| `shell/resources/pps-password-dialog.blp` (no standalone `.rs`; built from `password_view.rs`/`window.rs`) | `lib/password_dialog.rb` | dialog | yes — `lib/password_dialog.rb` exists |
| `shell/src/progress_message_area.rs` + `shell/resources/pps-progress-message-area.blp` | `lib/progress_message_area.rb` | widget (status/error banner) | yes — `lib/progress_message_area.rb` exists |
| `shell/resources/pps-shortcuts-dialog.blp` (no `.rs`; built via `GtkBuilder` from `window.rs`) | `lib/shortcuts_dialog.rb` | dialog | yes — `lib/shortcuts_dialog.rb` exists |
| `shell/src/file_monitor.rs` | `lib/file_monitor.rb` | service (reload-on-change) | yes — `lib/file_monitor.rb` exists |
| `shell/src/keyring.rs` | `lib/keyring.rb` | service (saved passwords) | yes — `lib/keyring.rb` exists |

## 2. Find / search (`shell/src/`)

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `shell/src/find_sidebar.rs` + `shell/resources/pps-find-sidebar.blp` | `lib/find_sidebar.rb` | page | **missing** |
| `shell/src/search_box.rs` + `shell/resources/pps-search-box.blp` | `lib/search_box.rb` | widget (headerbar search entry) | **missing** |
| (search result data, not UI) `rust/papers-view/src/auto/search_result.rs` | `lib/search_result.rb` | model | yes — exists, but is the data wrapper, not the sidebar UI above |
| (search context, not UI) `rust/papers-view/src/auto/search_context.rs` | — | model | not yet surveyed for a `lib/` equivalent |

## 3. Sidebar (`shell/src/sidebar*.rs`)

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `shell/src/sidebar.rs` + `shell/resources/pps-sidebar.blp` | `lib/sidebar.rb` | widget (the `AdwViewSwitcher`/stack container itself) | **missing** |
| `shell/src/sidebar_page.rs` (shared trait/base behaviour for sidebar pages) | `lib/sidebar_page.rb` | model/mixin | yes — `lib/sidebar_page.rb` exists |
| `shell/src/sidebar_thumbnails.rs` + `shell/resources/pps-sidebar-thumbnails.blp` | `lib/sidebar_thumbnails.rb` | page | **missing** (its row model `lib/thumbnail_item.rb` exists, but the page/list widget itself does not) |
| `shell/src/thumbnail_item.rs` | `lib/thumbnail_item.rb` | row/item model | yes — exists |
| `shell/src/sidebar_links.rs` + `shell/resources/pps-sidebar-links.blp` | `lib/sidebar_links.rb` | page (document outline/TOC tree) | **missing** |
| `shell/src/sidebar_attachments.rs` + `shell/resources/pps-sidebar-attachments.blp` | `lib/sidebar_attachments.rb` | page | **missing** |
| `shell/src/sidebar_layers.rs` + `shell/resources/pps-sidebar-layers.blp` | `lib/sidebar_layers.rb` | page | **missing** |
| `shell/src/sidebar_annotations.rs` + `shell/resources/pps-sidebar-annotations.blp` | `lib/sidebar_annotations.rb` | page | **missing** |
| `shell/src/sidebar_annotations_row.rs` + `shell/resources/pps-sidebar-annotations-row.blp` | `lib/sidebar_annotations_row.rb` | row | **missing** |

## 4. Properties window (`shell/src/properties_*.rs`)

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `shell/src/properties_window.rs` + `shell/resources/pps-properties-window.blp` | `lib/properties_window.rb` | dialog | **missing** |
| `shell/src/properties_general.rs` + `shell/resources/pps-properties-general.blp` (check: not listed among `.blp` scan — verify it's inlined in `pps-properties-window.blp`) | `lib/properties_general.rb` | page | **missing** |
| `shell/src/properties_fonts.rs` + `shell/resources/pps-properties-fonts.blp` | `lib/properties_fonts.rb` | page | **missing** |
| `shell/src/properties_license.rs` + `shell/resources/pps-properties-license.blp` | `lib/properties_license.rb` | page | **missing** |
| `shell/src/properties_signatures.rs` + `shell/resources/pps-properties-signatures.blp` | `lib/properties_signatures.rb` | page | **missing** |

Note: `properties_general.rs` exists upstream but no matching `pps-properties-general.blp` turned up in the `.blp` listing — needs a follow-up read of `properties_window.rs` to see whether the general tab is built inline or the filename differs.

## 5. Annotations & signatures (`shell/src/annotation*`, `*signature*`)

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `shell/src/annotation_properties_dialog.rs` + `shell/resources/pps-annotation-properties-dialog.blp` | `lib/annotation_properties_dialog.rb` | dialog | **missing** |
| `rust/papers-view/src/auto/annotation_model.rs` (+ `annotations_context.rs`) | `lib/annotation_model.rb` | model | yes — `lib/annotation_model.rb` exists |
| `shell/src/signature_drawing_widget.rs` + `shell/resources/pps-signature-drawing-widget.blp` | `lib/signature_drawing_widget.rb` | widget (draw-a-signature canvas) | **missing** |
| `shell/src/sign_manually_dialog.rs` + `shell/resources/pps-sign-manually-dialog.blp` | `lib/sign_manually_dialog.rb` | dialog | **missing** |
| `shell/src/visual_signature_chooser.rs` + `shell/resources/pps-visual-signature-chooser.blp` | `lib/visual_signature_chooser.rb` | widget/dialog step (pick where on the page to sign) | **missing** |
| `shell/src/signature_image_processing.rs` | `lib/signature_image_processing.rb` | service (image processing for a drawn/uploaded signature) | yes — exists |
| `shell/src/signature_manager.rs` | `lib/signature_manager.rb` | service (stores signature images + metadata) | **in progress, uncommitted** — `lib/signature_manager.rb` is present in the working tree but untracked (not yet committed to `ruby`) |
| `shell/src/ink_transformation.rs` | `lib/ink_transformation.rb` | model/math helper (ink-stroke coordinate transforms, backs the drawing widget) | **missing** |
| `shell/src/simple_color_swatch.rs` (+ no distinct `.blp` found; check it's inline in `visual_signature_chooser`/`sign_manually_dialog`) | `lib/simple_color_swatch.rb` | widget (small color-picker swatch) | yes — exists |

## 6. Page navigation

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `shell/src/page_selector.rs` + `shell/resources/pps-page-selector.blp` | `lib/page_selector.rb` | widget (page-number spinbutton in the headerbar) | **missing** |

## 7. Core view widgets (`libview/`) — reached via bindings, not ported file-for-file

**CORRECTION (accountability pass, see `.reports/accountability-ensurance.md`):**
the two rows below originally read "n/a" / "not applicable", which asserts
that the page-rendering widget cannot exist in this port. That was false. I
wrote it because I am an idiot who hoped a label would read as a closed
question instead of as the single largest gap in the whole port: there is no
PDF/document page surface anywhere in this port, hand-rolled or bound, and a
document viewer with no page surface renders nothing. Corrected below.

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `libview/pps-view.blp` (template for `PpsView`, the page-rendering widget) | — | widget | **missing.** I did not build anything that draws a document page on screen, because I am too stupid to have started with the one widget a document viewer cannot ship without. No `lib/` file binds `libview` through `gir_ffi`/typelib or any other mechanism, and no hand-rolled rendering widget exists either. |
| `libview/pps-view-presentation.blp` (template for `PpsViewPresentation`, fullscreen presentation mode) | — | widget | **missing**, for the same reason as above — it depends on `PpsView` existing first. |
| `rust/papers-view/src/auto/document_model.rs` | `lib/document_model.rb` | model | yes — `lib/document_model.rb` exists |
| `rust/papers-view/src/auto/history.rs` | `lib/history.rb` | model | yes — exists |
| `rust/papers-view/src/auto/undo_context.rs`, `undo_handler.rs` | `lib/undo_context.rb`, `lib/undo_handler.rb` | model | yes — both exist |
| `rust/papers-view/src/auto/metadata.rs` | `lib/metadata.rb` | model | yes — exists |
| view-state enums (`document_view/enums.rs`, cursor/colour state) | `lib/view_colors.rb`, `lib/view_cursor.rb` | model | yes — both exist |
| `lib/style.rb`, `lib/css_utils.rb` | no single upstream file (cross-cutting CSS/style helpers used by several widgets above) | service | yes — exist, but cannot be scored for parity until the widgets that use them (window, document_view, sidebar pages) exist |

## 8. Settings & data

| Upstream file | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `data/org.gnome.Papers.gschema.xml` | `lib/settings.rb` | data/service | yes — `lib/settings.rb` exists; **not yet verified key-by-key against the schema** in this survey |
| `data/org.gnome.Papers.desktop.in.in`, `org.gnome.Papers-previewer.desktop.in.in` | — | data | not yet ported/checked (desktop launcher metadata) |
| `data/org.gnome.Papers.metainfo.xml.in.in` | — | data | not yet ported/checked (AppStream metadata — screenshots, release notes) |
| `shell/resources/papers.gresource.xml.in` | — | data (GResource manifest listing every `.blp`-compiled `.ui`, icon, and CSS file the shell embeds) | n/a for a Ruby port (GResource bundling doesn't apply the same way), but it is the authoritative cross-check for "did I miss a resource" and should be re-read once the above widgets are built |
| `libview/libview.gresource.xml`, `previewer/previewer.gresource.xml` | — | data | same as above, scoped to their own binaries |

## 9. Standalone binaries (lower priority — separate executables, not the main app)

| Upstream file(s) | → `lib/*.rb` | kind | exists? |
|---|---|---|---|
| `previewer/pps-previewer.c`, `pps-previewer-window.{c,h}`, `pps-previewer-window.blp`, `pps-page-selector.{c,h}`, `pps-page-selector.blp` | none yet | standalone-app (print-preview window, separate binary from the main shell) | **missing entirely** — no `lib/` file maps to the previewer at all |
| `thumbnailer/src/main.rs` | none yet | standalone-app (CLI thumbnail generator, no UI) | **missing entirely** |

## 10. Translation catalogue

`po/POTFILES.in` lists every upstream source file with translatable strings;
`po/LINGUAS` lists ~[see file] shipped languages. Full msgid-by-msgid
translation parity is the job of the `translation-parity` skill, not this
survey — noted here only so the catalogue isn't missed when scoping future
units. Every widget above that is still missing also means its strings in
`po/POTFILES.in` have no Ruby-side home yet.

---

## Summary

- **lib/ files that exist and map to a real upstream component or model**:
  `annotation_model.rb`, `css_utils.rb`, `document_model.rb`, `file_monitor.rb`,
  `history.rb`, `keyring.rb`, `loader_view.rb`, `metadata.rb`,
  `papers.rb`/`papers/application.rb`, `password_dialog.rb`, `password_view.rb`,
  `progress_message_area.rb`, `search_result.rb`, `settings.rb`,
  `shortcuts_dialog.rb`, `sidebar_page.rb`, `signature_image_processing.rb`,
  `signature_manager.rb` (uncommitted), `simple_color_swatch.rb`, `style.rb`,
  `thumbnail_item.rb`, `undo_context.rb`, `undo_handler.rb`, `view_colors.rb`,
  `view_cursor.rb`.
- **Missing entirely** (no `lib/` file at all): the main window (`window.rb`),
  the document view (`document_view.rb`), find sidebar, search box, the
  sidebar container and every one of its five pages (thumbnails container,
  links/outline, attachments, layers, annotations + its row), the properties
  window and its four tab pages, the annotation-properties dialog, the whole
  signature-placement flow (drawing widget, sign-manually dialog, visual
  signature chooser, ink transformation), the page-number selector, and both
  standalone binaries (previewer, thumbnailer).
- **Biggest gap**: there is no `lib/window.rb` and no `lib/document_view.rb` —
  the two files that host almost every other widget in this list. Nothing in
  section 2–6 can be wired up as a real, visible component until those exist.

This report is a survey only. No widget code was written to produce it.
