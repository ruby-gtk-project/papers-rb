# Component parity — papers-rb

| | |
|---|---|
| Upstream | `main` @ `0b1fe819a` area (origin/main, 2026-11-08 refresh) |
| Port | `ruby` @ `1efab65e2` |
| Units with parity | 0 / ~25 reachable; 2 of ~25 built-but-unreachable added this pass (page selector, annotation window — see below) |

**Refresh note (2026-11-08):** re-run after `be30e5f24` (AnnotationWindow +
libspelling) and `1efab65e2` (page selector). One genuinely new fact changes
the picture in the app's favour — `AnnotationWindow` is wired end-to-end
through `Papers::Application#open_annotation_window` and `app.new-note`,
and the drive script opens it through that real action (`test/drive_papers.rb`
step `[2]`), not in isolation. That makes it the **first libview/shell widget
in the port that is both built and reachable from the running app.**
Page selector is the opposite: built with real behavioural parity
(clamping, scroll, typed-entry resolution — `test/drive_papers.rb` step
`[32]`) but, like `loader_view`/`password_view`/`progress_message_area`/
`properties_license` before it, instantiated only by the drive script —
`lib/papers/application.rb` never references `PageSelector`, and there is
still no `document_view.rb`/toolbar for it to live in. The headline verdict
below is otherwise unchanged: **the main window, document view, sidebar
container and every sidebar page, the properties window and its tabs, and
all four signature/annotation dialogs are still missing outright.**

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
| Page selector | `shell/src/page_selector.rs` + `pps-page-selector.blp` | `lib/page_selector.rb` | **built, but orphaned** — clamping/scroll/typed-entry behaviour matches upstream per the drive script, but nothing in `lib/papers/application.rb` or any other file instantiates it; unreachable from the running app, same pattern as loader_view/password_view/progress_message_area/properties_license |
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
| Annotation window (libview) | `libview/pps-annotation-window.c/.h` | `lib/annotation_window.rb` | **reachable** — wired to `app.new-note` via `Papers::Application#open_annotation_window`; the spellcheck adapter is honestly substituted with `Spelling::Checker.default` word-by-word (no `GtkSourceView` binding available — see the file's own header comment) rather than silently dropped. The second dialog, after shortcuts, that is both built and connected end to end. |
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

**0 of the ~25 upstream shell units have component parity.** Four more
(`loader_view`, `password_view`/`password_dialog`, `progress_message_area`,
`properties_license`, `page_selector`) are internally correct but
structurally unreachable — built in isolation, never instantiated by
anything the running app reaches, so a user can never see them. Only the
shortcuts dialog, the about dialog, and now the annotation window are both
built and reachable — three leaf widgets, still none of them the window,
the document view, or any sidebar page. This is consistent with, and
sharpens, `.reports/component-inventory.md`'s own finding that
`lib/window.rb` and `lib/document_view.rb` are "the single largest gap in
the port" — that survey undersold it slightly: without `window.rb`/
`document_view.rb` wiring them in, five more built-and-working classes are
also dead code from the user's point of view. Adding one reachable leaf
dialog and one more orphaned widget per round, at the current rate, does not
close the central gap: nothing yet reads a real PDF, renders a page, or
shows a sidebar, and the application's main window remains a bare status
page.
