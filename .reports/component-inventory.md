# Component inventory — papers-rb vs. upstream (origin/main)

Opening survey of the `ruby` fork, built with the `component-identification`
skill's method. Upstream is Rust/GTK4/Libadwaita (`gnome.org/Papers`, the
Evince successor), with widget trees declared in `.blp` and backed by a `.rs`
class in `shell/src/` (app layer), `previewer/` (standalone previewer binary)
or `libview/` (the reusable document-view widgets, no app chrome). `libdocument/`
is the non-UI backend (PDF/DjVu/TIFF/comics parsing) and is out of scope for a
widget inventory — it has no user-facing component.

Columns: **upstream file(s)** the component is built from, the **lib/\*.rb**
path it should become (house style: one port file per upstream unit), **kind**
(window / dialog / page / sidebar-page / row / widget / menu / schema /
catalog / shortcuts / action-set), and whether `lib/` on `ruby` already has it.

## Application shell

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `shell/src/application.rs` | `lib/papers/application.rb` | application class (actions: `app.new`, `app.quit`, `app.help`, `about`) | Yes |
| `shell/src/main.rs` | `exe/papers` | entry point | Yes |
| `shell/src/window.rs`, `shell/resources/pps-window.blp` | `lib/window.rb` | main window (`Adw.ApplicationWindow`; actions `win.close`, `win.fullscreen`, `win.night-mode`, `win.open`, `win.presentation`, `win.escape`; header bar, toolbar view, menu) | **No** |
| `shell/src/deps.rs` | — | build-time dependency shim, not a component | N/A |
| `shell/src/file_monitor.rs` | `lib/file_monitor.rb` | file-change watcher (behaviour, not a widget) | Yes |
| `shell/src/keyring.rs` | `lib/keyring.rb` | libsecret-backed cert/key storage (behaviour) | **No** |
| `data/org.gnome.Papers.gschema.xml` | `lib/settings.rb` | GSettings schema (3 schemas: `org.gnome.Papers`, `.Default`, `.Previewer`) | Partial — `lib/settings.rb` exists; verify it covers all 3 schemas incl. `Previewer` |
| `shell/resources/papers.gresource.xml.in`, `shell/resources/meson.build` | — | GResource manifest (lists every `.blp`→`.ui` + `papers.css` compiled in) | N/A (Ruby port has no `.ui`/GResource by house style) |
| `shell/resources/papers.css` | `lib/style.rb` (+ `lib/css_utils.rb`, `lib/view_colors.rb`) | app stylesheet / CSS-class helpers | Yes (helpers) — confirm class coverage against `papers.css` |
| `po/*.po`, `po/POTFILES.in`, `po/LINGUAS` | — | translation catalogue (104 locales) | Out of scope here — see `translation-parity` skill |

## Document view (the central page)

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `shell/src/document_view.rs`, `document_view/{actions,enums,io,print,signals}.rs`, `shell/resources/pps-document-view.blp` | `lib/document_view.rb` (+ split per house style if large) | page — the loaded-document view (toolbar, view+sidebar split, actions, print, I/O) | **No** |
| `shell/src/loader_view.rs`, `shell/resources/pps-loader-view.blp` | `lib/loader_view.rb` | page — loading/empty/error state shown before a document is ready | Yes |
| `shell/src/password_view.rs`, `shell/resources/pps-password-view.blp` | `lib/password_view.rb` | page — "document is encrypted" state | Yes |
| `shell/src/password_view.rs` (`PasswordDialog` struct), `shell/resources/pps-password-dialog.blp` | `lib/password_dialog.rb` | dialog — password prompt (`Adw.AlertDialog`) | Yes |
| `shell/src/progress_message_area.rs`, `shell/resources/pps-progress-message-area.blp` | `lib/progress_message_area.rb` | widget — inline progress/error banner | Yes |
| `shell/src/find_sidebar.rs`, `shell/resources/pps-find-sidebar.blp` | `lib/find_sidebar.rb` | sidebar page — search results list | **No** |
| `shell/src/search_box.rs`, `shell/resources/pps-search-box.blp` | `lib/search_box.rb` | widget — the find entry in the header bar | **No** |

## Sidebar and its pages

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `shell/src/sidebar.rs`, `shell/resources/pps-sidebar.blp` | `lib/sidebar.rb` | widget — the sidebar container (`Adw.ViewSwitcher`/stack of pages) | **No** |
| `shell/src/sidebar_page.rs` | `lib/sidebar_page.rb` | base class / interface each sidebar page implements | Yes |
| `shell/src/sidebar_thumbnails.rs` | `lib/sidebar_thumbnails.rb` | sidebar page — page thumbnails | **No** |
| `shell/src/thumbnail_item.rs` | `lib/thumbnail_item.rb` | row — one thumbnail list-item model/widget | Yes |
| `shell/src/sidebar_links.rs`, `shell/resources/pps-sidebar-links.blp` | `lib/sidebar_links.rb` | sidebar page — table of contents / outline tree | **No** |
| `shell/src/sidebar_attachments.rs`, `shell/resources/pps-sidebar-attachments.blp` | `lib/sidebar_attachments.rb` | sidebar page — file attachments list | **No** |
| `shell/src/sidebar_layers.rs`, `shell/resources/pps-sidebar-layers.blp` | `lib/sidebar_layers.rb` | sidebar page — optional-content-group (layers) tree | **No** |
| `shell/src/sidebar_annotations.rs`, `shell/resources/pps-sidebar-annotations.blp` | `lib/sidebar_annotations.rb` | sidebar page — annotations list | **No** |
| `shell/src/sidebar_annotations_row.rs`, `shell/resources/pps-sidebar-annotations-row.blp` | `lib/sidebar_annotations_row.rb` | row — one annotation entry in that list | **No** |

## Properties dialog

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `shell/src/properties_window.rs`, `shell/resources/pps-properties-window.blp` | `lib/properties_window.rb` | dialog — document properties (`Adw.PreferencesWindow`/dialog hosting the tabs below) | **No** |
| `shell/src/properties_general.rs` (no standalone `.blp`; a page inside the window template) | `lib/properties_general.rb` | page — general metadata tab (title, author, dates, etc.) | **No** |
| `shell/src/properties_fonts.rs`, `shell/resources/pps-properties-fonts.blp` | `lib/properties_fonts.rb` | page — fonts-used tab | **No** |
| `shell/src/properties_license.rs`, `shell/resources/pps-properties-license.blp` | `lib/properties_license.rb` | page — document license tab | **No** |
| `shell/src/properties_signatures.rs`, `shell/resources/pps-properties-signatures.blp` | `lib/properties_signatures.rb` | page — digital-signature validation tab | **No** |

## Annotations and signing

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `shell/src/annotation_properties_dialog.rs`, `shell/resources/pps-annotation-properties-dialog.blp` | `lib/annotation_properties_dialog.rb` | dialog — per-annotation color/author/icon editor | **No** |
| `libview/context/pps-annotation-model.c` | `lib/annotation_model.rb` | model — annotation list model | Yes |
| `shell/src/simple_color_swatch.rs` | `lib/simple_color_swatch.rb` | widget — one color swatch button | Yes |
| `shell/src/signature_drawing_widget.rs`, `shell/resources/pps-signature-drawing-widget.blp` | `lib/signature_drawing_widget.rb` | widget — freehand signature canvas | **No** |
| `shell/src/visual_signature_chooser.rs`, `shell/resources/pps-visual-signature-chooser.blp` | `lib/visual_signature_chooser.rb` | dialog — pick/draw/type/upload a signature image | **No** |
| `shell/src/sign_manually_dialog.rs`, `shell/resources/pps-sign-manually-dialog.blp` | `lib/sign_manually_dialog.rb` | dialog — place a signature on the page before signing | **No** |
| `shell/src/signature_manager.rs` | `lib/signature_manager.rb` | behaviour — PKCS#11/cert enumeration and signing flow | **No** |
| `shell/src/signature_image_processing.rs` | `lib/signature_image_processing.rb` | behaviour — raster processing for drawn/uploaded signatures | **No** |
| `shell/src/ink_transformation.rs` | `lib/ink_transformation.rb` | behaviour — stroke coordinate transforms for ink annotations | **No** |

## Shortcuts, undo, and other chrome

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `shell/resources/pps-shortcuts-dialog.blp` (no dedicated `.rs`; built by `window.rs`) | `lib/shortcuts_dialog.rb` | dialog — `Gtk.ShortcutsWindow` | Yes |
| `libview/context/pps-undo-context.c` | `lib/undo_context.rb` | model — undo/redo stack | Yes |
| `libview/context/pps-undo-handler.c` | `lib/undo_handler.rb` | interface each undoable action implements | Yes |
| `libview/context/pps-metadata.c` | `lib/metadata.rb` | per-document metadata store (zoom, page, sidebar state) | Yes |
| `libview/context/pps-document-model.c` | `lib/document_model.rb` | model — current document/page/scale state | Yes |
| `libview/context/pps-search-result.c` | `lib/search_result.rb` | model — one find-match result | Yes |
| `libview/pps-view-cursor.c` | `lib/view_cursor.rb` | behaviour — cursor shape per interaction mode | Yes |
| `libview/pps-css-utils.c` | `lib/css_utils.rb` | behaviour — CSS color/class helpers | Yes |

## The document view widget itself (`libview/`)

These are the heaviest gap: the actual page-rendering widgets have no port
file yet, even though several of their supporting models (above) do.

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `libview/pps-view.c`, `libview/pps-view.blp` | `lib/view.rb` | widget — the scrollable multi-page document canvas | **No** |
| `libview/pps-view-page.c` | `lib/view_page.rb` | widget/row — one rendered page inside the view | **No** |
| `libview/pps-view-presentation.c`, `libview/pps-view-presentation.blp` | `lib/view_presentation.rb` | widget — fullscreen presentation-mode view | **No** |
| `libview/pps-annotation-layer.c`, `-ink.c`, `-objects.c` | `lib/annotation_layer.rb` (+ ink/objects) | widget — annotation overlay drawn on a page | **No** |
| `libview/pps-annotation-overlay.c` | `lib/annotation_overlay.rb` | widget — per-page annotation event layer | **No** |
| `libview/pps-annotation-window.c` | `lib/annotation_window.rb` | widget — popover shown when an annotation is activated | **No** |
| `libview/pps-form-overlay.c` | `lib/form_overlay.rb` | widget — interactive form-field layer | **No** |
| `libview/pps-overlay.c` | `lib/overlay.rb` | base widget the above overlays share | **No** |
| `libview/pps-print-operation.c` | `lib/print_operation.rb` | behaviour — print dialog/job wiring | **No** |
| `libview/factory/pps-annotation-widget-factory.c`, `pps-element-widget-factory.c`, `pps-form-widget-factory.c` | `lib/*_widget_factory.rb` | widget factories for `ListView`/overlay items | **No** |
| `libview/context/pps-annotations-context.c`, `pps-attachment-context.c`, `pps-search-context.c`, `pps-history.c` | `lib/*.rb` (one each) | models — annotations/attachments/search/navigation-history state | **No** |

## Previewer (second binary, `previewer/`)

Standalone print-preview app with its own window; the gemspec currently
declares only one executable (`papers`), so this entire binary is unstarted.

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `previewer/pps-previewer.c` | `lib/previewer/main.rb` (or new `exe/papers-previewer`) | entry point | **No** |
| `previewer/pps-previewer-window.c`, `previewer/pps-previewer-window.blp` | `lib/previewer/window.rb` | window — print-preview chrome | **No** |
| `previewer/pps-page-selector.c`, `previewer/pps-page-selector.blp` | `lib/previewer/page_selector.rb` | widget — page-range picker, also used standalone in `shell/resources/pps-page-selector.blp` | **No** |
| `previewer/previewer.gresource.xml` | — | GResource manifest | N/A |

## Nautilus extension (`nautilus/`)

| Upstream file(s) | lib/*.rb | Kind | Exists |
|---|---|---|---|
| `nautilus/pps-nautilus-extension.c` | — | Nautilus properties-page extension (GObject module loaded by Files, not by the app) | **No** — likely out of scope for the Ruby app port; flag rather than silently build |

## Backend libraries (`libdocument/`) — not components

`libdocument/` (PDF/Poppler, DjVu, TIFF, comic-archive backends and the
`pps-document*` model/interface classes) has no `.blp`/UI and produces no
widget rows — it is the document-parsing core the view widgets above call
into. It belongs in a separate, non-widget port inventory (document loading,
rendering, text/forms/annotations data access), not this component survey.

## Totals

- Upstream user-facing component units identified: **47** (app shell: 2 behaviour
  helpers + 1 window; document-view area: 7; sidebar: 8; properties dialog: 5;
  annotations/signing: 9; shortcuts/undo/chrome: 7 ported already; `libview`
  rendering widgets: 11; previewer: 4; nautilus: 1).
- Already present in `lib/` on `ruby`: **21** files, covering mostly the
  model/behaviour layer (settings, document/annotation models, undo, metadata,
  search result, thumbnail item, simple color swatch, progress area, loader
  view, password view/dialog, shortcuts dialog, file monitor, style/CSS/cursor
  helpers) plus the application class and sidebar-page base.
- Entirely missing: the main **window**, the **document view** page and all of
  its **sidebar pages** and **rows**, the full **properties dialog** (all four
  tabs), the entire **signing/signature** flow (6 components), the **core
  rendering widgets** in `libview/` (the view, view-page, presentation mode,
  annotation/form overlays — 11 components with no port file at all), and the
  **previewer** binary (4 components, no second executable declared yet).
- This is a survey only; no `lib/*.rb` was written or changed as part of it.
