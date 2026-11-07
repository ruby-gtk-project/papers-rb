# Component parity — papers-rb

| | |
|---|---|
| Upstream | `main` @ `b6e5dcf` area (origin/main, 2026-11-07 clone) |
| Port | `ruby` @ `1cf0bfddd` |
| Units with parity | 0 / ~25 |

This ledger is built on top of `.reports/component-inventory.md` (the
component-identification survey) and on a direct widget-token scan of
`shell/resources/*.blp` (upstream) against `lib/*.rb` (port). It is a
whole-app scan, not yet a widget-by-widget walk of every unit, because the
scan already answers the only question that matters at this stage: **does
the unit exist at all.** Of the ~25 units upstream's shell builds (window,
document view, 6 sidebar pages, 5 properties pages/dialog, 4 annotation/
signature dialogs, page selector, search box, find sidebar, previewer,
thumbnailer), the port builds **zero** of them. Everything that exists in
`lib/` is backend/model code and three leaf dialogs (shortcuts, password,
about) hung off `Papers::Application`'s stub status page.

## Whole-app widget scan

| Axis | Upstream distinct (shell/resources/*.blp only) | Port distinct (lib/*.rb) | Upstream occurrences | Port occurrences |
|---|---:|---:|---:|---:|
| Widget types | 35 | 34 | 181 | 68 |

This table alone understates the gap, because the upstream count above is
**only the `.blp` templates**; it excludes every widget `shell/src/*.rs`
builds in code (the page selector's `Gtk.SpinButton`, the document view's
`Gtk.GestureClick`/`Gtk.EventControllerKey` interactions, the sidebar's
`Gtk.ListView` + `Gtk.SignalListItemFactory` rows, the properties window's
tree model, the signature canvas's `Gtk.GestureDrag`). None of those source
files have a port counterpart at all (see the file-mapping table below), so
their widgets are not a "4 vs 2" style gap — they are a "whole file" gap.
A type-count table that looks close (35 vs 34) is exactly the shape this
skill warns about: it balances a missing main window against the port's own
thirty-odd backend/model/leaf-dialog widgets built for compartments upstream
doesn't have, and reports near-parity on a port with no document viewer in
it. **Do not read 35≈34 as near-parity — read the file-mapping table.**

## File mapping (unit by unit)

| Upstream unit | Upstream file(s) | Port file | Verdict |
|---|---|---|---|
| Application shell / actions | `shell/src/application.rs` | `lib/papers/application.rb` | partial — actions/accels for about/help/quit/new/shortcuts exist; `win.open`, `win.close`, `win.fullscreen`, `win.night-mode`, `win.presentation` are bound to accelerators (`Application::ACCELS`) but target a window (`Papers::Application#window`) that has no `open`, `close`, `fullscreen`, `night-mode` or `presentation` action installed anywhere — **dead accelerators**, five of them |
| Main window | `shell/src/window.rs` + `pps-window.blp` | — | **gap**. `Application#window` builds a bare `Adwaita::ApplicationWindow` with a status page; no header bar document title, no sidebar/document `Adw.OverlaySplitView`, no toolbar, no search toggle |
| Document view | `shell/src/document_view.rs` (+`actions.rs`,`io.rs`,`print.rs`,`signals.rs`) + `pps-document-view.blp` | — | **gap** — no file |
| Page selector | `shell/src/page_selector.rs` + `pps-page-selector.blp` | — | **gap** — no file |
| Find sidebar / search box | `shell/src/find_sidebar.rs`, `shell/src/search_box.rs` + their `.blp` | — | **gap** — no file for either |
| Sidebar container | `shell/src/sidebar.rs` + `pps-sidebar.blp` | — | **gap** — no file |
| Sidebar: thumbnails | `shell/src/sidebar_thumbnails.rs` + `.blp` | `lib/thumbnail_item.rb` (row model only) | **gap** — the list/page widget itself does not exist; only its row data class does |
| Sidebar: links/outline | `shell/src/sidebar_links.rs` + `.blp` | — | **gap** |
| Sidebar: attachments | `shell/src/sidebar_attachments.rs` + `.blp` | — | **gap** |
| Sidebar: layers | `shell/src/sidebar_layers.rs` + `.blp` | — | **gap** |
| Sidebar: annotations (+ row) | `shell/src/sidebar_annotations*.rs` + `.blp` | — | **gap** |
| Properties window | `shell/src/properties_window.rs` + `.blp` | — | **gap** |
| Properties: general | `shell/src/properties_general.rs` | — | **gap** |
| Properties: fonts | `shell/src/properties_fonts.rs` + `.blp` | — | **gap** |
| Properties: license | `shell/src/properties_license.rs` + `.blp` | `lib/properties_license.rb` | **built, but orphaned** — the class itself has parity-worthy behaviour (rows show/hide by license fields, matches upstream's logic per the drive script) but nothing in the port ever instantiates it from a live properties window, because no properties window exists. It is unreachable from the running app. |
| Annotation properties dialog | `shell/src/annotation_properties_dialog.rs` + `.blp` | — | **gap** |
| Signature drawing widget | `shell/src/signature_drawing_widget.rs` + `.blp` | — | **gap** (`lib/ink_transformation.rb` has the math; no widget) |
| Sign-manually dialog | `shell/src/sign_manually_dialog.rs` + `.blp` | — | **gap** |
| Visual signature chooser | `shell/src/visual_signature_chooser.rs` + `.blp` | — | **gap** |
| Loader view | `shell/src/loader_view.rs` + `.blp` | `lib/loader_view.rb` | built, same orphaning problem — nothing wires it into `window`/`document_view` because neither exists |
| Password view / dialog | `shell/src/password_view.rs`, `pps-password-dialog.blp` | `lib/password_view.rb`, `lib/password_dialog.rb` | built, same orphaning problem |
| Progress message area | `shell/src/progress_message_area.rs` + `.blp` | `lib/progress_message_area.rb` | built, same orphaning problem |
| Shortcuts dialog | `pps-shortcuts-dialog.blp` | `lib/shortcuts_dialog.rb` | **reachable** — wired to `app.shortcuts`, the one dialog the port actually connects end to end |
| Previewer (separate binary) | `previewer/*` | — | **gap** — no `exe/`/`lib/` file at all |
| Thumbnailer (separate binary) | `thumbnailer/*` | — | **gap** — no `exe/`/`lib/` file at all |

## Behaviour axis (Step 5 spot-check)

Drove the five window accelerators listed above against the built app
(`test/drive_papers.rb` plus manual `signal_emit`): `win.open`, `win.close`,
`win.fullscreen`, `win.night-mode`, `win.presentation` are bound via
`Gtk::Application#set_accels_for_action`, but `Gtk::Application#add_action`
is only ever called for the five `app.*` names in
`Application#setup_actions`. Pressing `Ctrl+O` in the running app raises no
error and does nothing, because GTK resolves an unbound action to a no-op.
This is a component-parity gap in its own right (an accelerator that exists
and silently does nothing is worse than one that is simply absent, since the
user has reason to believe it should work) and it is not listed in the
existing `component-inventory.md`, so it is a net-new finding of this pass.

## Stylesheet axis

Upstream's CSS is `shell/resources/papers.css`. The port's is `lib/style.rb`
(a Ruby heredoc, loaded via `Style.install_shell` → `Gtk::CssProvider`). A
byte-level diff was not performed for the whole file in this pass, but the
`pps-view` / `pps-view.inverted` selectors and the dark-mode `FIXME` block
were checked and are a verbatim copy, confirming the port is tracking
upstream's stylesheet directly rather than reinventing it — this part is
sound as far as it goes. It cannot be scored for *attachment* parity (which
classes actually land on which widgets) because the widgets that would carry
most of these classes (`pps-view`, the sidebar rows, the toolbar buttons)
do not exist in the port yet.

## Verdict

**0 of the ~25 upstream shell units have component parity.** Three more
(`loader_view`, `password_view`/`password_dialog`, `progress_message_area`,
`properties_license`) are internally correct but structurally unreachable —
built in isolation, never instantiated by anything the running app reaches,
so a user can never see them. Only the shortcuts dialog and the about dialog
are both built and reachable. This is consistent with, and sharpens,
`.reports/component-inventory.md`'s own finding that `lib/window.rb` and
`lib/document_view.rb` are "the single largest gap in the port" — that
survey undersold it slightly: without `window.rb`/`document_view.rb` wiring
them in, four more built-and-working classes are also dead code from the
user's point of view.
