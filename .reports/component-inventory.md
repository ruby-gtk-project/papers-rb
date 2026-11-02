# papers-rb — upstream component inventory

Survey of `origin/main` (GNOME Papers, Rust + blueprint + C) against `lib/` on
the `ruby` branch. Read with the `component-identification` skill: a component
is one widget tree *plus* its CSS classes, signals, actions and owner, and
upstream splits almost every component across a `.rs` (or `.c`) file and a
`.blp` file — the component is the **set** of files, and both halves collapse
into one `lib/*.rb`.

Upstream references are `git show origin/main:<path>`. Nothing below exists in
the port yet except the application stub.

## Totals

| | Upstream | `ruby` branch |
|---|---:|---:|
| Blueprint files (`.blp`) | 29 | 0 (by design — widgets are memoized methods) |
| Blueprint template/named roots | 31 | — |
| Shell Rust sources (`shell/src`) | 39 files, ~16 400 lines | — |
| libview UI sources (`libview/*.c`) | 25 files | — |
| Menu models (`menu … { }`) | 8 | 0 |
| GSettings schemas / keys | 2 schemas (`org.gnome.Papers`, `.Default`), 27 keys | 0 |
| GResource manifests | 3 (`shell`, `previewer`, `libview`) | — |
| `po/` catalogue | 102 languages, ~476 messages | 0 |
| `help/` (Mallard user guide) | 60 C pages, 36 languages | 0 |
| `lib/*.rb` files | — | 3 (`papers.rb`, `papers/application.rb`, `papers/rb/version.rb`) |

The port is a stub: `lib/papers/application.rb` is one `Adw.StatusPage` saying
the port has not been written. Every row below that is marked absent is
genuinely absent, not "partially there".

## Reading order

Components are listed in the order a user meets them: the application, the
window and its five states, the document view and its chrome, the sidebar
pages, search, the dialogs, then the view/render layer, the previewer and the
thumbnailer.

## 1 — Application

### `shell/src/main.rs`, `shell/src/application.rs` → `lib/papers/application.rb` — present (stub)

Not a widget class, but it owns the app-level actions, the accelerators and the
About dialog.

| Item | × | Detail |
|---|---:|---|
| `Gtk.Application` (`Adw.Application` upstream) | 1 | app id `org.gnome.Papers`, `HANDLES_OPEN \| HANDLES_COMMAND_LINE` |
| Actions | 4 | `app.about`, `app.help`, `app.quit`, `app.new` |
| Accelerators | 9 | `app.help`=F1, `app.new`=⌃N, `app.quit`=⌃Q, `win.open`=⌃O, `win.close`=⌃W, `win.fullscreen`=F11, `win.night-mode`=⌃I, `win.presentation`=F5/⇧F5 |
| `Adw.AboutDialog` | 1 | `from_appdata` over `data/org.gnome.Papers.metainfo.xml.in.in`; copyright, translator-credits, developers (12), documenters, version, debug info |
| Command line | 1 | `--page-label`, `--page-index`, `--named-dest`, `--fullscreen`, `--presentation`, `--preview`, `--find`, `--version` (see `setup_command_line`) |
| Help | 1 | `app.help` → `help:papers` via `Gtk.UriLauncher` |

### `data/org.gnome.Papers.gschema.xml` → `lib/settings.rb` — absent

27 keys over two schemas. `org.gnome.Papers`: `override-restrictions`,
`document-directory`, `pictures-directory`, `page-cache-size`,
`allow-links-change-zoom`, `night-mode`. `org.gnome.Papers.Default`:
`enable-spellchecking`, `show-sidebar`, `window-width/height`,
`window-maximized`, `fullscreen`, `sizing-mode`, `zoom`, `continuous`,
`dual-page`, `dual-page-odd-left`, `sidebar-page`, `annot-color`, `pen-color`,
`pen-stroke`, `highlight-color`, `highlight-stroke`, `eraser-radius`,
`eraser-mode-objects`, `text-color`, `last-used-signature-id`,
`signature-last-placed-scale`. Bound directly from `pps-window.blp` and
`pps-document-view.blp` as `Gio.Settings` objects with `changed::` handlers.

### `shell/resources/papers.css`, `previewer/papers-previewer.css` → `lib/style.rb` — absent

The stylesheet side of every CSS class the widgets apply (`zoom-overlay`,
`box-circular`, `padded`, `reference-bar`, `annotation-content`,
`nobold-label`, `pps-annotation-window`, `overlay-form`, `content-view`…). A
class applied and never defined is a visual gap even when the widget is right.

## 2 — Window and its states

### `shell/src/window.rs` + `shell/resources/pps-window.blp` → `lib/window.rb` — absent

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template `PpsWindow`) | 1 | — | `notify::fullscreened` → `window_fullscreened` | 600×600, min 360×360 |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | |
| `Adw.ViewStack` `stack` | 1 | — | — | six pages: `start`, `error`, `password`, `loader`, `document`, `presentation` |
| `Adw.ToolbarView` | 2 | — | — | start and error pages |
| `Adw.HeaderBar` | 2 | — | — | |
| `MenuButton` | 1 | — | `menu-model: app_menu`, primary | "Main Menu" |
| `Adw.StatusPage` (start) | 1 | — | — | **empty state**: "Open a Document" / "Drag and drop documents here", icon `x-office-document-symbolic` |
| `Button` `open_button` | 1 | `suggested-action`, `pill` | `win.open` | "_Open…" |
| `Adw.StatusPage` `error_page` | 1 | — | — | **error state**: "Unable to Open Document", icon `dialog-error-symbolic` |
| `Button` (error) | 1 | `suggested-action`, `pill` | `win.open` | "_Open Other File…" |
| `DropTarget` | 1 | — | `drop` → `drag_data_received` | `GdkFileList`, copy |
| `ShortcutController` / `Shortcut` | 1 | — | Escape → `win.escape` | on the presentation page |
| `Adw.AlertDialog` `error_alert` | 1 | — | `close` | load/save error reporting |
| Actions | 6 | — | `win.open`, `win.close`, `win.fullscreen`, `win.escape`, `win.night-mode` (stateful), `win.presentation` | |

`menu app_menu` → one section, 3 items: `app.shortcuts`, `app.help`,
`app.about`.

Behaviour in `window.rs` beyond the tree: remote-file copy and reload, document
modified check on close, presentation start/stop, metadata init, night mode
(`Adw.StyleManager`), file-dialog folder restore per `UserDirectory`, external
URI launch.

### `shell/src/loader_view.rs` + `pps-loader-view.blp` → `lib/loader_view.rb` — absent

Loading state: `Adw.Bin` → `Adw.ToolbarView` + `Adw.HeaderBar` +
`Adw.WindowTitle`, `Adw.StatusPage` ("Loading Document", description bound to
`template.uri`), `Adw.Clamp` → `Stack` with `Adw.Spinner` (64×64) and
`ProgressBar` pages, and a `Button` (`pill`) "C_ancel" → `cancel_clicked`,
emitting the `cancel` signal the window listens for.

### `shell/src/password_view.rs` + `pps-password-view.blp` → `lib/password_view.rb` — absent

Locked state: `Adw.StatusPage` "Password Required", icon
`dialog-password-symbolic`, `Button` (`pill`) "_Unlock Document" →
`open_unlock_dialog`. Owns a `Gio.SimpleActionGroup action_group` carrying the
`password.preference` stateful action. Signals `unlock(password, flags)` and
`cancelled`. Talks to `lib/keyring.rb`.

### `shell/resources/pps-password-dialog.blp` (built from `password_view.rs`) → `lib/password_dialog.rb` — absent

`Adw.AlertDialog` "Password Required", responses `cancelled`/`unlock`
(`unlock` disabled until input). `PasswordEntry password_entry` (peek icon,
32 chars, `changed` → `update_password`), `Label error_message` (`error`,
"Invalid password"), and two `CheckButton`s bound to
`password.preference` with targets `"never"` / `"permanently"`.

### `shell/src/keyring.rs` → `lib/keyring.rb` — absent

Secret Service lookup/save/delete of document passwords (label
`org.gnome.Papers.Document`, attributes `type`/`uri`). Not a widget, but the
password flow is wrong without it.

### `shell/src/file_monitor.rs` → `lib/file_monitor.rb` — absent

`GObject` wrapper over `Gio.FileMonitor` emitting `changed`; drives the
"document changed on disk" reload banner.

## 3 — Document view

### `shell/src/document_view.rs` + `document_view/{actions,io,print,signals,enums}.rs` + `pps-document-view.blp` (1 749 lines) → `lib/document_view.rb` + `lib/document_view/{actions,io,print,signals,enums}.rb` — absent

The largest component in the app. Upstream file → port file, one to one:

| Upstream | → | Kind |
|---|---|---|
| `shell/src/document_view.rs` (971 ln) + `pps-document-view.blp` | `lib/document_view.rb` | view |
| `shell/src/document_view/actions.rs` (1 481 ln) | `lib/document_view/actions.rb` | actions |
| `shell/src/document_view/io.rs` (916 ln) | `lib/document_view/io.rb` | behaviour (open/save/copy) |
| `shell/src/document_view/print.rs` (370 ln) | `lib/document_view/print.rb` | behaviour (printing) |
| `shell/src/document_view/signals.rs` (933 ln) | `lib/document_view/signals.rb` | behaviour (signal wiring) |
| `shell/src/document_view/enums.rs` (79 ln) | `lib/document_view/enums.rb` | enums |

Widget tree (template `PpsDocumentView: Adw.BreakpointBin`):

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.BreakpointBin` | 1 | — | — | min 360×200 |
| `Adw.Breakpoint` | 2 | — | — | `max-width: 720sp` collapses the split view; `max-width: 540sp` also hides `page_selector` |
| `Adw.OverlaySplitView` `split_view` | 1 | — | `notify::show-sidebar`, `notify::collapsed` | sidebar 210–300px, pinned |
| `Adw.ToolbarView` | 2 | — | — | sidebar and content |
| `Adw.HeaderBar` | 2 | — | — | sidebar bar and `header_bar` |
| `Revealer` | 1 | — | `reveal-child: bind find_button.sensitive` | wraps the find button |
| `ToggleButton` `find_button` | 1 | — | `doc.toggle-find` | `edit-find-symbolic`, "Search" |
| `Adw.WindowTitle` | 2 | — | — | "Document Viewer"; document title |
| `MenuButton` `action_menu_button` | 1 | — | `sidebar_menu`, primary | "Main Menu" |
| `MenuButton` `document_menu_button` | 1 | — | `document_menu` | "Document Menu", `view-more-symbolic` |
| `ToggleButton` `sidebar_button` | 1 | — | `doc.show-sidebar` | `sidebar-show-symbolic` |
| `Stack` `sidebar_stack` | 1 | — | — | crossfade between `PpsSidebar` and `PpsFindSidebar` |
| `Adw.Banner` `banner` | 1 | — | `button-clicked` → `view_banner_cancelled` | loading/saving progress banner |
| `Adw.Banner` `signature_banner` | 1 | — | `button-clicked` → `view_signature_details` | "Document has been digitally signed." / "View Signature…" |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | |
| `Overlay` | 1 | — | — | hosts the two floating toolbars over the scroller |
| `Box` `zoom_toolbar` | 1 | `zoom-overlay` | — | floating, bottom-end |
| `Revealer` `zoom_fit_best_revealer` | 1 | — | — | crossfade |
| `Button` (zoom) | 3 | `circular`, `card` | `doc.sizing-mode('automatic')`, `doc.zoom-in` (sensitive←`view.can-zoom-in`), `doc.zoom-out` (←`can-zoom-out`) | "Fit Automatically", "Zoom In", "Zoom Out" |
| `Separator` | 2 | `spacer` | — | |
| `Box` `annot_toolbar` | 1 | `zoom-overlay` | — | floating annotation toolbar |
| `Box` (toolbar shell) | 1 | `box-circular`, `card` | — | |
| `Revealer` `draw_revealer` | 1 | — | — | slide-left |
| `MenuButton` (annotation settings) | 8 | `circular`, `flat`, some `padded` | popovers `text_color`, `text_font`, `highlight_color`, `highlight_stroke`, `pencil_color`, `pencil_stroke`, `eraser_radius`; menu `eraser-settings-menu` | each `visible:` bound to `is_text` / `is_highlight` / `is_pencil` / `is_eraser` over the annotation model's tool — **conditional** |
| `SimpleColorSwatch` | 3 | — | color bound to `text-color`, `highlight-color`, `pen-color` | app widget, see §7 |
| `Adw.ToggleGroup` `tool_switcher` | 1 | `flat`, `round` | `active-name` ↔ `annotation-model.active-tool-str` | |
| `Adw.Toggle` | 4 | — | — | `text` (Insert Text), `pencil` (Draw), `highlighter` (Highlight), `eraser` (Erase Annotations) |
| `Button` `draw_button` | 1 | `circular`, `flat` | `doc.toggle-edit-mode` | "Edit Document" |
| `ScrolledWindow` `scrolled_window` | 1 | — | `scroll-child` → `scroll_child_history` | |
| `PpsView` `view` | 1 | — | `external-link`, `handle-link`, `popup`, `selection-changed`, `scroll`, `layers-changed`, `cursor-moved`, `signature-rect` | see §7 |
| `PopoverMenu` `view_popup` | 1 | — | `view-popup-menu`, `closed` → `view_popup_closed` | no arrow |
| `GestureClick` | 1 | — | `pressed` → `button_pressed` | button 0 |
| `ShortcutController` | 1 | — | **34 `Shortcut`s** | see the accelerator table below |
| `Adw.AlertDialog` `rect_small_alert` | 1 | — | `response` → `signature_rect_too_small` | "Selection too Small", `Start _Over` / `_Sign` (destructive) |
| `Adw.AlertDialog` `print_cancel_alert` | 1 | — | `response` → `print_cancel_alert_response` | "Abort Printing?", `Abort _Print and Close` (destructive) / `_Cancel` / `Close _After Printing` (suggested) |
| `Adw.AlertDialog` `error_alert` | 1 | — | `close` | |
| Non-widget objects | — | — | `PpsDocumentModel model` (9 `notify::` handlers + `page-changed`), `PpsAnnotationModel`, `PpsHistory` (`activate-link`, `changed`), `PpsUndoContext`, `PpsAnnotationsContext`, `PpsAttachmentContext`, two `Gio.Settings`, `Gio.SimpleActionGroup document_action_group` | the `doc.` action group lives here |

**`doc.` actions (64)** installed in `document_view/actions.rs`:
`add-manual-signature`, `add-text-annotation`, `annot-color`,
`annot-properties`, `annot-textmarkup-type`, `caret-navigation`, `continuous`,
`copy`, `copy-email-address`, `copy-image`, `copy-link-address`,
`create-signature`, `digital-signing`, `dual-odd-left`, `dual-page`,
`edit-annot`, `enable-spellchecking`, `eraser-mode-objects`, `eraser-radius`,
`escape`, `find`, `find-next`, `find-previous`, `go-back-history`,
`go-backwards`, `go-first-page`, `go-forward`, `go-forward-history`,
`go-last-page`, `go-next-page`, `go-previous-page`, `go-to-link`,
`highlight-color`, `highlight-stroke`, `manual-signing`, `open-attachment`,
`open-copy`, `open-link`, `open-link-new-window`, `open-with`, `pen-color`,
`pen-stroke`, `print`, `redo`, `remove-annot`, `rotate-left`, `rotate-right`,
`rtl`, `save-as`, `save-attachment`, `save-image`, `select-all`, `select-page`,
`send-email`, `show-properties`, `show-sidebar`, `sizing-mode`, `text-color`,
`toggle-edit-mode`, `toggle-find`, `undo`, `zoom`, `zoom-in`, `zoom-out`.

**In-view accelerators (34 `Shortcut`s)**: ⌃⇧O open-with; ⌃F / `/` / KP_Divide
find; ⌃G / F3 find-next; ⌃⇧G / ⇧F3 find-previous; ⇧PgDn / ⇧PgUp
go-forward/backwards; ⌥N / Forward and ⌥P / Back history; Escape; F7 caret;
⌃P print; ⌃⇧N open-copy; ⌃S / ⌃⇧S save-as; ⌥Return properties; ⌃C / ⌃Insert
copy; ⌃L select-page; ⌃← / ⌃→ rotate; `h` `k` `u` `q` text-markup types; F9
sidebar; `w` `f` `a` sizing modes; ⌃0 / ⌃KP_0 zoom 1.0; `s` add text
annotation; `c` continuous; `d` dual; `o` odd-left; `n` / ⌃PgDn and `p` / ⌃PgUp
page; `+ = KP_Add` zoom-in; `- KP_Subtract` zoom-out; ⌃Z undo; ⌃⇧Z redo;
⌃⌥S digital-signing.

### Menus in `pps-document-view.blp` → `lib/document_view.rb` — absent

| Menu | Items | Notes |
|---|---:|---|
| `sidebar_menu` | 8 | Open…, (night mode), Keyboard Shortcuts, Help, About — `win.open`, `win.night-mode`, `app.shortcuts`, `app.help`, `app.about` |
| `document_menu` | 14 | Print…, Fullscreen, Present as Slideshow / Sign Digitally…, Manage Signatures… / Open a Copy, Open With…, Save As… / Continuous, Dual, Odd Pages Left, Right to Left / Rotate ⤵ / Document Properties |
| `view-popup-menu` | 15 + 2 dynamic sections | link, email, copy/select-all, image, attachment, `annot_menu` section, annotation properties/remove, add text annotation, `signature_menu` section — all `hidden-when: action-disabled` |
| `eraser-settings-menu` | 2 | `doc.eraser-mode-objects` targets `false` / `true` |
| `annot_menu_child` (`Box`) | — | custom popover content: text-markup `ToggleButton` group, color swatches |
| `signature_menu_child`, `signature_menu_manage_child`, `signature_menu_no_signature` (`Box`) | 3 | custom menu slots; the last is the **empty state** "No Signatures Yet" + "Add Signature" (`pill`, `suggested-action`) |

### Annotation popovers in `pps-document-view.blp` → `lib/document_view.rb` — absent

Seven `Popover`s, each a color palette or a stroke-size picker:
`text_font_popover`, `text_color_popover`, `highlight_color_popover`,
`highlight_stroke_popover`, `pencil_color_popover`, `pencil_stroke_popover`,
`eraser_radius_popover`. Colors come from the `palette` set in `actions.rs`
(`yellow`, `orange`, `red`, `purple`, `blue`, `green`, `black`, `custom`,
`none`) — a **repeater** driven by that list, not nine literal widgets.

## 4 — Sidebar

### `shell/src/sidebar.rs` + `pps-sidebar.blp` → `lib/sidebar.rb` — absent

`Adw.Bin` → `Adw.ToolbarView` with `Adw.ViewStack stack`
(`notify::visible-child` → `visible_child_changed`) and a bottom
`Adw.InlineViewSwitcher` (`flat`, icons, homogeneous). Five pages, declared in
`pps-document-view.blp`: `thumbnails` (grid-large-symbolic, "Thumbnails"),
`links` (outline-symbolic, "Outline", default), `annotations`
(chat-bubble-text-symbolic), `attachments` (mail-attachment-symbolic), `layers`
(view-paged-symbolic). Signal `navigated-to-view`.

### `shell/src/sidebar_page.rs` → `lib/sidebar_page.rb` — absent

Abstract `Adw.Bin` subclass with `document-model` and `sidebar` construct-only
properties, plus a vfunc class struct (`supports_document`). Every sidebar page
below derives from it, so it has to exist first.

| Upstream | → | Kind | Present |
|---|---|---|---|
| `shell/src/sidebar_thumbnails.rs` + `pps-sidebar-thumbnails.blp` | `lib/sidebar_thumbnails.rb` | sidebar page | absent |
| `shell/src/thumbnail_item.rs` | `lib/thumbnail_item.rb` | list item model | absent |
| `shell/src/sidebar_links.rs` + `pps-sidebar-links.blp` | `lib/sidebar_links.rb` | sidebar page | absent |
| `shell/src/sidebar_annotations.rs` + `pps-sidebar-annotations.blp` | `lib/sidebar_annotations.rb` | sidebar page | absent |
| `shell/src/sidebar_annotations_row.rs` + `pps-sidebar-annotations-row.blp` | `lib/sidebar_annotations_row.rb` | list row | absent |
| `shell/src/sidebar_attachments.rs` + `pps-sidebar-attachments.blp` | `lib/sidebar_attachments.rb` | sidebar page | absent |
| `shell/src/sidebar_layers.rs` + `pps-sidebar-layers.blp` | `lib/sidebar_layers.rb` | sidebar page | absent |

Details worth not losing:

- **Thumbnails**: `ScrolledWindow` → `Adw.ClampScrollable clamp` (max 240,
  tightening 180) → `GridView grid_view` (`navigation-sidebar`, 1 column,
  accessibility label "Previews") with a `SignalListItemFactory`
  (setup/bind/unbind) over `SingleSelection(Gio.ListStore)`;
  `notify::scale-factor` → `reload`. Items are `PpsThumbnailItem`
  (text, paintable, binding, job) — a repeater over the page count.
- **Links (outline)**: `ListView` (`navigation-sidebar`) over
  `SingleSelection` (`autoselect: false`, `selection-changed`), factory
  setup/bind/unbind, plus `PopoverMenu popup` (`links-menu`) and a
  `Gio.SimpleActionGroup action_group` carrying `links.collapse-all`,
  `links.expand-all`, `links.expand-all-under`, `links.print-section`.
  1 000 lines upstream — tree expansion state is the bulk of it.
- **Annotations**: `Adw.ViewStack` with an `empty` page
  (`Adw.StatusPage`, `compact`, "No Annotations", `chat-bubble-text-symbolic`)
  and an `annot` page (`ListView`, `navigation-sidebar`, `SingleSelection`),
  plus `PopoverMenu popup` over `menu annotation-popup` (5 items: Edit Note,
  Annotation Properties, Remove Annotation, _Open Attachment,
  _Save Attachment As…, all `hidden-when: action-disabled`).
- **Annotations row**: `Box` (vertical, 6) → header `Box` with
  `Label page_label` (`heading`), `Image image`, `Label author_label`
  (`caption`); reference `Box` with `Adw.Bin` (`reference-bar`) and
  `Label reference_label` (3 lines, wrap, ellipsize); `Label content_label`
  (`annotation-content`, markup).
- **Attachments**: `ScrolledWindow` + `GestureClick` (button 0, `pressed` →
  `button_clicked`) → `ListView` with `MultiSelection`, rubberband,
  `activate` → `list_view_item_activated`; drag-out to save, context menu for
  open/save.
- **Layers**: `ListView` (`single-click-activate`) over `NoSelection`,
  factory setup/bind/unbind, `activate` → `list_view_activate`; emits
  `visibility-changed`.

## 5 — Search

### `shell/src/find_sidebar.rs` + `pps-find-sidebar.blp` → `lib/find_sidebar.rb` — absent

`Adw.Bin` → `Box` with `PpsSearchBox` and a `Stack results_stack` of four
pages: `results` (`ScrolledWindow` → `ListView`, `navigation-sidebar`,
factory setup/bind/unbind), `loading` (`Adw.Spinner` 32×32), `no-results`
(**empty state**: `Adw.StatusPage`, `compact`, `edit-find-symbolic`, "No
Results Found" / "Try a different search"), `initial` (**initial state**:
"Perform a Search" / "The search results will appear here"). Default visible
child `initial`.

### `shell/src/search_box.rs` + `pps-search-box.blp` → `lib/search_box.rb` — absent

`Adw.Bin` → `Box` with `SearchEntry entry` (32 chars, 500 ms delay,
placeholder "Search in document", `activate`, `next-match`, `previous-match`,
`stop-search`, a `ShortcutController` binding ⇧Return to
`doc.find-previous`, accessibility `labelled-by`) and a `MenuButton` (`flat`,
`view-more-symbolic`, "Search Options") over `menu search_options`
(`search.whole-words-only`, `search.case-sensitive`).

## 6 — Chrome, properties and dialogs

| Upstream | → | Kind | Present |
|---|---|---|---|
| `shell/src/page_selector.rs` + `shell/resources/pps-page-selector.blp` | `lib/page_selector.rb` | widget | absent |
| `shell/src/progress_message_area.rs` + `pps-progress-message-area.blp` | `lib/progress_message_area.rb` | message area | absent |
| `shell/src/properties_window.rs` + `pps-properties-window.blp` | `lib/properties_window.rb` | dialog | absent |
| `shell/src/properties_general.rs` (no `.blp` — built in code) | `lib/properties_general.rb` | dialog page | absent |
| `shell/src/properties_fonts.rs` + `pps-properties-fonts.blp` | `lib/properties_fonts.rb` | dialog page | absent |
| `shell/src/properties_license.rs` + `pps-properties-license.blp` | `lib/properties_license.rb` | dialog page | absent |
| `shell/src/properties_signatures.rs` + `pps-properties-signatures.blp` | `lib/properties_signatures.rb` | dialog page | absent |
| `shell/src/annotation_properties_dialog.rs` + `pps-annotation-properties-dialog.blp` | `lib/annotation_properties_dialog.rb` | dialog | absent |
| `shell/src/sign_manually_dialog.rs` + `pps-sign-manually-dialog.blp` | `lib/sign_manually_dialog.rb` | dialog | absent |
| `shell/src/visual_signature_chooser.rs` + `pps-visual-signature-chooser.blp` | `lib/visual_signature_chooser.rb` | dialog page | absent |
| `shell/src/signature_drawing_widget.rs` + `pps-signature-drawing-widget.blp` | `lib/signature_drawing_widget.rb` | widget | absent |
| `shell/src/signature_manager.rs` | `lib/signature_manager.rb` | store | absent |
| `shell/src/signature_image_processing.rs` | `lib/signature_image_processing.rb` | helper | absent |
| `shell/src/ink_transformation.rs` | `lib/ink_transformation.rb` | helper | absent |
| `shell/src/simple_color_swatch.rs` | `lib/simple_color_swatch.rb` | widget | absent |
| `shell/resources/pps-shortcuts-dialog.blp` (no backing source) | `lib/shortcuts_dialog.rb` | dialog | absent |

Details:

- **Page selector**: `Box` (`numeric`, insensitive until loaded) with
  `Entry entry` (3 chars, `xalign 0.9`, accessibility label "Select page",
  `activate` → `activated`, `EventControllerScroll` vertical|discrete →
  `page_scrolled`, `EventControllerFocus` `leave` → `focused_out`) and a
  `Label label` (5 chars, insensitive) showing "of N" / the page label.
- **Progress message area**: `Adw.Bin` → `InfoBar` (close button,
  `message-type: other`) with `Image` (48px), `Label label`,
  `Label secondary_label` (hidden), `Label progress_label`, `ProgressBar`.
- **Properties window**: `Adw.Dialog` 500×600, `Adw.HeaderBar` (strict
  centering) with `Adw.ViewSwitcher` over `Adw.ViewStack` of four pages:
  `general`, `fonts`, `license`, `signatures` (each with title, underline and
  icon; `fonts`/`license`/`signatures` pages shown conditionally).
- **Properties general** (396 lines, no blueprint): `Adw.PreferencesPage` of
  `Adw.ActionRow`s built in code — title, location, subject, author, keywords,
  producer, creator, created, modified, number of pages, optimized, format,
  security, paper size, size, contains JS… each row **conditional** on the
  field being present. Read the file; the scan cannot see these.
- **Properties fonts**: `Adw.ViewStack` with a `load` page (`Adw.Spinner`) and
  a `fonts` page (`Adw.PreferencesPage` → `Adw.PreferencesGroup` →
  `ListBox list_box`, `boxed-list`) — a repeater over the font list job.
- **Properties license**: `Adw.Clamp` → `Box` with `license_box` ("Usage
  Terms" `heading`, `ScrolledWindow` with framed selectable `Label license`
  (`body`, `link`)) and `uri_box` — both **conditional**.
- **Properties signatures**: `Adw.PreferencesPage signatures_page` filled
  dynamically — one group per signature, a repeater.
- **Annotation properties dialog**: `Adw.Dialog` (360 wide) →
  `Adw.PreferencesPage` → `Adw.PreferencesGroup` with `Adw.ActionRow` +
  `ColorDialogButton color` (`notify::rgba` → `property_changed`),
  `Adw.SpinRow opacity` (0–100, adjustment), `Adw.ComboRow icon` (hidden;
  10-string `StringList`: Note, Comment, Key, Help, New Paragraph, Paragraph,
  Insert, Cross, Circle, Unknown), `Adw.ComboRow markup_type` (hidden;
  Highlight, Strike out, Underline, Squiggly), `Adw.EntryRow author`
  (apply button), `Adw.SwitchRow popup_state` ("Auto-Reveal on _Scroll").
- **Sign manually dialog**: `Adw.Dialog` (400 wide) → `Adw.NavigationView`
  with two `Adw.NavigationPage`s: `chooser` (`Adw.ToastOverlay` →
  `PpsVisualSignatureChooser`) and `new-signature` (`Adw.Bin draw_page` →
  `ScrolledWindow` → `PpsSignatureDrawingWidget`).
- **Visual signature chooser**: `ScrolledWindow` → `Stack signatures_stack`
  with a zero-height `Box`, an **empty state** `Adw.StatusPage empty_state`
  (`compact`, `signature-symbolic`, "No Signatures" / "Create a signature by
  drawing or opening an image", `Button empty_add_button` `pill`
  `suggested-action` → `navigation.push('new-signature')`), and
  `ListBox signatures_listbox` (`boxed-list`) with
  `Adw.ButtonRow add_signature_row` ("Add Signature",
  `list-add-symbolic`). Signature rows are a repeater over the manager's list.
- **Signature drawing widget**: `Box` → `Frame` (`card`) → `Overlay` with
  `Label placeholder_label` (`dim-label`, "Draw your signature here") over
  `DrawingArea drawing_area` (200 high), then a `CenterBox` with
  `Button undo_button` / `redo_button` (`flat`, `circular`, insensitive),
  `Button import_button` (`flat`, `clicked` → `on_choose_file_clicked`,
  `Image` + `Label` "Import") and `Button insert_button`
  (`suggested-action`, `pill`, insensitive).
- **Shortcuts dialog**: `Adw.ShortcutsDialog` with **9
  `Adw.ShortcutsSection`s** — File (6), Window (4), Selection (2), Zoom and
  Rotation (9), Navigation (13), Document View (12), Search (3), General (5),
  Presentation Mode (…) — every item a `title` + `accelerator` pair. No
  backing source file; it is its own unit.
- **Simple color swatch**: app `Gtk.Widget` subclass with a `color` property,
  snapshot-drawn rounded rect (`graphene`/`gsk`). Used 3× in the annotation
  toolbar and in the color popovers.

## 7 — View and render layer (`libview`)

User-facing widgets, all absent. These are C upstream with blueprint for the
two `Widget` subclasses.

| Upstream | → | Kind | Present |
|---|---|---|---|
| `libview/pps-view.c/.h` + `pps-view.blp` + `pps-view-private.h` | `lib/view.rb` | view widget | absent |
| `libview/pps-view-page.c` | `lib/view_page.rb` | widget | absent |
| `libview/pps-view-presentation.c` + `.blp` | `lib/view_presentation.rb` | window/view | absent |
| `libview/pps-annotation-window.c` | `lib/annotation_window.rb` | popup window | absent |
| `libview/pps-annotation-overlay.c` | `lib/annotation_overlay.rb` | overlay | absent |
| `libview/pps-annotation-layer.c` | `lib/annotation_layer.rb` | overlay | absent |
| `libview/pps-annotation-layer-ink.c` | `lib/annotation_layer_ink.rb` | overlay | absent |
| `libview/pps-annotation-layer-objects.c` | `lib/annotation_layer_objects.rb` | overlay | absent |
| `libview/pps-form-overlay.c` | `lib/form_overlay.rb` | overlay | absent |
| `libview/pps-overlay.c` | `lib/overlay.rb` | interface | absent |
| `libview/factory/pps-element-widget-factory.c` | `lib/element_widget_factory.rb` | factory | absent |
| `libview/factory/pps-form-widget-factory.c` | `lib/form_widget_factory.rb` | factory | absent |
| `libview/factory/pps-annotation-widget-factory.c` | `lib/annotation_widget_factory.rb` | factory | absent |
| `libview/pps-print-operation.c` | `lib/print_operation.rb` | print dialog | absent |
| `libview/pps-view-cursor.c` | `lib/view_cursor.rb` | helper | absent |
| `libview/pps-colors.c` | `lib/colors.rb` | helper | absent |
| `libview/pps-css-utils.c` | `lib/css_utils.rb` | helper | absent |
| `libview/pps-page-cache.c` | `lib/page_cache.rb` | cache | absent |
| `libview/pps-pixbuf-cache.c` | `lib/pixbuf_cache.rb` | cache | absent |
| `libview/pps-job.c`, `pps-jobs.c`, `pps-job-scheduler.c` | `lib/job.rb`, `lib/jobs.rb`, `lib/job_scheduler.rb` | async jobs | absent |
| `libview/pps-debug.c` | `lib/debug.rb` | helper | absent |

Details:

- **`PpsView`** (`pps-view.blp`): `Widget` subclass, CSS `content-view`,
  `has-tooltip`, focusable, and **12 event controllers / gestures** —
  `GestureClick` (button 0, press/release), `EventControllerMotion`,
  `EventControllerScroll` (vertical, zoom), `EventControllerFocus`,
  `GestureZoom` (capture), `GestureDrag` ×3 (selection, middle-click pan,
  signing), `GestureSwipe` ×2 (middle-click, touch page swipe),
  `EventControllerScroll` (kinetic both axes, page scroll), `GestureLongPress`
  (touch context menu). Signals emitted: `external-link`, `handle-link`,
  `popup`, `selection-changed`, `scroll`, `layers-changed`, `cursor-moved`,
  `signature-rect`.
- **`PpsViewPresentation`** (`pps-view-presentation.blp`): `Widget` with
  `EventControllerScroll`, `EventControllerKey`, `EventControllerMotion`,
  `EventControllerFocus` (inhibits/uninhibits the screen lock),
  `GestureClick` ×2 (primary → next, secondary → previous), and a
  `Popover goto_popup` with `Label` "Jump to page:" + `Entry goto_entry`.
  Also black/white screen states and slide transitions over
  **11 GLSL shaders** (`libview/shader/*.glsl`: fade, split, wipe, box, push,
  cover, uncover, blinds, dissolve, fly, glitter).
- **Annotation window**: `Gtk.Window` with CSS class
  `pps-annotation-window`, `Adw.HeaderBar`, `Label` (author), a
  `ScrolledWindow` with `GtkSourceView` (spell-checked note body, falling back
  to `Gtk.TextView`), and its own `Gtk.CssProvider` for the annotation color.
- **Form overlay**: builds a widget per form field — `Gtk.Entry`,
  `Gtk.TextView`/`GtkSourceView`, `Gtk.CheckButton`, `Gtk.Button`,
  `Gtk.ComboBox` ×2 with `Gtk.CellRendererText`, `Gtk.TreeView` +
  `Gtk.ListStore`, plus `GestureClick` and `EventControllerFocus`; CSS classes
  `overlay-form` and `view`. A repeater over the page's form fields.
- **Print operation**: `Gtk.PrintOperation` / `Gtk.PrintDialog` with a custom
  "Page Handling" tab — `Gtk.Grid`, `Gtk.Label`, `Gtk.DropDown` (page scaling)
  and 3 `Gtk.CheckButton`s (auto-rotate, shrink to fit, print as image), and an
  `Adw.AlertDialog` for print errors.

### Contexts and models (`libview/context`) — all absent

One upstream file each, bound directly from the blueprints, so they are part of
the component surface rather than back-end detail:

| Upstream | → |
|---|---|
| `libview/context/pps-document-model.c` | `lib/document_model.rb` |
| `libview/context/pps-annotation-model.c` | `lib/annotation_model.rb` |
| `libview/context/pps-annotations-context.c` | `lib/annotations_context.rb` |
| `libview/context/pps-attachment-context.c` | `lib/attachment_context.rb` |
| `libview/context/pps-history.c` | `lib/history.rb` |
| `libview/context/pps-metadata.c` | `lib/metadata.rb` |
| `libview/context/pps-search-context.c` | `lib/search_context.rb` |
| `libview/context/pps-search-result.c` | `lib/search_result.rb` |
| `libview/context/pps-undo-context.c` | `lib/undo_context.rb` |
| `libview/context/pps-undo-handler.c` | `lib/undo_handler.rb` |

## 8 — Previewer and thumbnailer (separate binaries)

| Upstream | → | Kind | Present |
|---|---|---|---|
| `previewer/pps-previewer.c` | `lib/previewer.rb` | application | absent |
| `previewer/pps-previewer-window.c` + `pps-previewer-window.blp` | `lib/previewer_window.rb` | window | absent |
| `previewer/pps-page-selector.c` + `previewer/pps-page-selector.blp` | `lib/previewer_page_selector.rb` | widget | absent |
| `thumbnailer/src/main.rs` | `lib/thumbnailer.rb` | CLI | absent |
| `nautilus/pps-nautilus-extension.c` | — | out of scope | absent |

Previewer window: `Adw.ApplicationWindow` 600×600 → `Adw.ToolbarView`
(`raised_border`) → `Adw.HeaderBar` with `Button go-previous-page`
(`go-up-symbolic`), `Button go-next-page` (`go-down-symbolic`),
`PpsPageSelector`, and at the end `Button print` ("_Print",
`suggested-action`), `Button zoom-out`, `Button zoom-default`,
`Button zoom-in`; content `ScrolledWindow` → `PpsView`. Plus
`Adw.AlertDialog dialog` "Failed to Print Document". Actions:
`win.go-previous-page`, `win.go-next-page`, `win.print`, `win.zoom-in`,
`win.zoom-out`, `win.zoom-default`. Its page selector differs from the shell's
(5-char entry, different handler names) — a separate component, not a reuse.

## 9 — Localisation

`po/` carries **102 languages** and ~476 messages; `help/` carries 60 Mallard
pages in **36 languages**. `po/POTFILES.in` lists 74 source files, including
every `.blp` above and `data/org.gnome.Papers.gschema.xml`. Every user-visible
string quoted in this inventory is a `_()` / `C_()` call upstream and needs the
same treatment in the port (see the `translation-parity` skill).

## Blockers

1. **No Ruby binding for the document back-end.** `libdocument` is a C library
   (`pps-document*.c`, ~45 files) with Poppler, DjVu, TIFF and comics back-ends
   behind it, exposed to the Rust shell as the `papers-document` GIR. Nothing
   in the port can load a PDF until this is settled: wrap the installed
   `libppsdocument` via GObject-Introspection, bind Poppler directly, or stub
   it. Every component in §3–§7 depends on the answer.
2. **`libview` is C, not Rust.** `PpsView`, `PpsViewPresentation`, the
   annotation and form overlays and the job scheduler come from the
   `libppsview` GIR, not from shell source. Deciding whether the port
   re-implements the view widget in Ruby or binds `libppsview` changes roughly
   half the inventory. Re-implementing means porting ~20 000 lines of C
   including a GPU render path and 11 GLSL shaders.
3. **Secret Service / keyring.** `shell/src/keyring.rs` uses `oo7`; the port
   needs a Ruby equivalent (libsecret via GI) or password saving is lost.
4. **Digital signatures.** `signature_manager.rs`,
   `signature_image_processing.rs` and the `libdocument` signature API depend
   on Poppler's signing support; no Ruby equivalent exists today.
5. **GtkSourceView dependency.** The annotation note window and text form
   fields use `GtkSourceView` for spell-checking, which the port's dev shell
   must provide before `lib/annotation_window.rb` can be written.
6. **Blueprint-only components have no handler file.** The shortcuts dialog is
   defined entirely in `pps-shortcuts-dialog.blp`; its 9 sections and ~55
   accelerator rows have to be read off the blueprint.
7. **Printing.** `libview/pps-print-operation.c` wraps `Gtk.PrintOperation`
   with a custom page-handling tab and an export path through
   `PpsFileExporter`; the Ruby bindings' coverage of `Gtk::PrintOperation` and
   `Gtk::PrintDialog` needs checking before `lib/print_operation.rb`.
8. **The `nautilus` extension is out of scope** for a Ruby port (it is a C
   shared object loaded by Nautilus) and is excluded from the component list.
