# Test parity — papers-rb

| | |
|---|---|
| Upstream | `main` @ `origin/main` (archived 2026-11-07) |
| Port | `ruby` @ `1efab65e2` |
| Upstream tests | 7 |
| Ported | 0 |
| Gaps | 7 |
| Test command (port) | `nix develop --command xvfb-run -a ruby test/drive_papers.rb` |
| Test command (upstream) | `meson test` (GLib), `cargo test` (Rust `sys` crates), `./thumbnailer-test.sh` (shell) |

## Census

Upstream's actual GLib/Rust test suite is tiny — most of "testing" for this
app is the manual flatpak procedure in `TESTING.md`, not an automated suite —
but it is not zero, and the skill's rule is that the count is the count,
never rounded down to "upstream barely tests itself anyway":

| # | Upstream test | File | Purpose | Port test | State |
|---|---|---|---|---|---|
| 1 | `/libview-jobs/get_annots` | `libview/tests/test-pps-jobs.c:88` | a `PpsJobLoad` + `PpsJobGetText`-style job loads a document and returns its annotations | — | **gap** |
| 2 | `/libview-jobs/load_encrypted` | `libview/tests/test-pps-jobs.c:89` | loading a password-protected document reports the right encrypted/wrong-password job state instead of crashing or silently failing | — | **gap** |
| 3 | `cross_validate_constants_with_c` | `rust/papers-document/sys/tests/abi.rs:117` | the Rust FFI struct/constant layout for `papers-document` matches what the C headers actually define | — | **gap** (binding-layer; Ruby has no analogous sys crate, but the underlying guarantee — that the Ruby binding's idea of the C struct/constant layout matches reality — is still owed; see Findings below) |
| 4 | `cross_validate_layout_with_c` | `rust/papers-document/sys/tests/abi.rs:151` | same, for struct memory layout | — | **gap** |
| 5 | `cross_validate_constants_with_c` | `rust/papers-view/sys/tests/abi.rs:117` | same, for `papers-view` | — | **gap** |
| 6 | `cross_validate_layout_with_c` | `rust/papers-view/sys/tests/abi.rs:151` | same, for `papers-view` struct layout | — | **gap** |
| 7 | `thumbnailer-test.sh` smoke test | `thumbnailer/thumbnailer-test.sh` | the `papers-thumbnailer` binary, given a document, produces a `thumbnail.png` and exits cleanly | — | **gap** — the port ships no thumbnailer binary at all (see `.reports/component-inventory.md` §9), so this cannot even be attempted yet |

Cross-checked against the build files: `libview/tests/meson.build` declares
exactly one test target (`pps-jobs-test`, wrapping both `g_test_add_func`
calls in row 1/2), so there is nothing registered that the census missed.
`libdocument/backend/comics/test-pps-archive.c` is **not** a test — it is a
`main()`-based CLI debugging tool for listing archive contents, with no
`g_test_add_func` anywhere in it — and is correctly excluded from the count.

None of the 7 have a named counterpart in the port. The port's test tree
(`test/drive_papers.rb`, `test/gtk_driver.rb`) does not test document
loading, annotation extraction, encrypted-document handling, FFI layout, or
thumbnail generation at all — it cannot, because the port has not built a
document model that opens a real PDF/annotation backend, nor a thumbnailer.
**0 of 7 upstream tests are ported, and the three behaviours they pin
(annotations load correctly, a wrong password is reported instead of
crashing, a thumbnail generator produces a usable PNG) are still owed.**

## The runtime gate, read correctly

The round's gate was reported as `drive_ok=true, 147 checks passed, 0
failed, covering 28 components`. Running it directly reproduces that:

```
nix develop --command xvfb-run -a ruby test/drive_papers.rb
...
147 of 147 checks passed
DRIVE OK
```

This is real — the command runs, under the fork's own dev shell and a
virtual display, and all 147 named checks do pass. But it is still a
**narrow** gate, and the drive script's own header comment has not changed
to say otherwise:

> "since `application.rb` wires almost nothing else into the running window
> yet — \[this script] builds and exercises every other widget and model
> class the port ships \[...] directly, the same way the window would if it
> used them."

One thing did change since the last pass (`98d879712`): `AnnotationWindow`
is now opened by step `[2]` *through* the real `app.new-note` action, not
built in isolation — the first time a step in this file has actually driven
the window to produce a widget rather than constructing that widget by
hand. That is real, incremental progress against this report's own
complaint. Everything else in the gate is unchanged in kind: 30 of the 33
named steps (`[10]`–`[32]`, covering `PageSelector` — new this round — plus
`LoaderView`, `PasswordDialog`/`PasswordView`, `ProgressMessageArea`,
`SimpleColorSwatch`, `SidebarPage`, `DocumentModel`, `AnnotationModel`,
`History`, `UndoContext`, `ThumbnailItem`, `SearchResult`, `FileMonitor`,
`Keyring`, `Metadata`, `SignatureImageProcessing`, `SignatureManager`,
`InkTransformation`, `ViewColors`, `ViewCursor`, `CssUtils`,
`PropertiesLicense`) are still instantiated and poked **directly**,
bypassing the main window entirely — because the main window
(`lib/window.rb`), the document view (`lib/document_view.rb`), and every
sidebar/properties widget that would actually wire them together **still
do not exist** (`.reports/component-inventory.md` §1–6, and
`.reports/component-parity.md`). "147 of 147 checks passed" is therefore
still not evidence that the app works end to end; it is evidence that one
more leaf dialog is now wired in and ~22 backend/leaf classes work in
isolation — a real and useful signal, but a different and much smaller
claim than "the app's 28 components are integration-tested." A component no
check exercises *through the real window* is unverified at the level a user
experiences the app, regardless of how many unit-style checks exercise its
class directly. This gate passing and the app still having no document
viewer, no sidebar, and five dead keyboard accelerators (see
`component-parity.md`) are not in tension — they are the same fact stated
twice, for a second consecutive round.

## Extra

- `test/drive_papers.rb` + `test/gtk_driver.rb` — 147 checks across 33 named
  steps (`[0]`–`[32]`), driving: application build, window/toolbar/menu
  construction, the shortcuts and about dialogs, settings round-trip to
  disk, stylesheet parsing, the annotation window (now through the real
  `app.new-note` action), and ~22 backend/model/leaf-widget classes listed
  above, most still exercised directly rather than through the window. None
  of these were written from an upstream test; they are new coverage for
  the port's own classes and are not parity work (per the skill's rule,
  they stay listed here, outside the 0/7 count, and are not double-counted
  as if they closed any of the 7 gaps above).

## Findings for `FINDINGS.md` (binding/architecture notes, not excuses)

- Rows 3–6 (the Rust `sys` ABI cross-checks) have no direct Ruby analogue
  because the port talks to the C libraries through `gir_ffi`/typelib
  introspection rather than a hand-written `sys` crate — introspection reads
  the real GIR at runtime, so a struct-layout mismatch is a different kind of
  failure (an exception at call time) rather than a silently wrong read. This
  makes the *specific* Rust test inapplicable in its literal form, but it does
  not make the underlying guarantee closed: nothing in this port currently
  asserts that opening a real PDF through the port's `DocumentModel` actually
  returns correct text/annotation data, which is what rows 1–2 are really
  about. That remains a gap regardless of how row 3–6's mechanism differs.

## Round update (2026-11-08, `ruby` @ `2e31575ce`)

Re-ran the gate after `2e31575ce` ("Port the main window",
`shell/src/window.rs` + `pps-window.blp` → `lib/window.rb`):

```
nix develop --command xvfb-run -a ruby test/drive_papers.rb
...
163 of 163 checks passed
DRIVE OK
```

This matches the round's reported gate exactly: `drive_ok=true`, 163 checks,
0 failed, 34 components (steps `[0]`–`[34]`, 35 named steps — one, step
`[0]`, title says "the window builds and shows the empty state" rather than
driving a component by name, so "34 components" counts the steps that name
one). This is a real increase over the previous round's 147/28: `window.rb`
now exists, is driven directly (steps `[0]`–`[9]` build it, flip its
`Gtk::Stack` through "start"/"error"/"password"/"loader", exercise its
`win.*` actions and accelerators through real `Gio::SimpleAction`
dispatch), and the shortcuts/about dialogs and `app.new` are now opened
through the window's own menu button rather than constructed standalone.
That is a genuine narrowing of the gap this report flagged last round (a
dead `win.open` accelerator): `win.open`, `win.close`, `win.fullscreen`,
`win.night-mode` are now installed by `window.rb#build` and checked by step
`[6]` ("every app action setup_actions installs is present and enabled").

**It is still not evidence that the 7 upstream-test gap closed, and it is
still not evidence of integration-level parity for the app's core job.**
Nothing in the 163 checks opens a real PDF, renders a page, extracts text,
walks an outline, or lists an attachment — because `lib/view.rb`
(`libview/pps-view.c`, 7745 lines, the core page renderer) and
`lib/document_view.rb` (`shell/src/document_view.rs`) still do not exist
(`.reports/component-inventory.md` is unchanged on this point). Step `[3]`
("win.open runs a real file through content-type detection to the error
page") is the closest the gate gets to document loading, and its own name
says where it stops: every file, including a real PDF, currently resolves
to the *error* page, because no `PpsDocument` backend is registered. The
7 upstream tests this ledger owes (annotation extraction, encrypted-document
handling via two job tests, two Rust ABI cross-checks, one thumbnailer smoke
test) remain **0/7 ported**, unchanged from last round — none of their
subject matter (a document backend, a thumbnailer binary) exists yet to
test.

**Still no `spec/` suite.** `spec/spec_helper.rb` and `spec/README.md` are
the only files under `spec/`; `find spec -name '*_spec.rb'` returns nothing.
`rake spec` has never been run against a real example in this port — there
are no examples. This is a gap in its own right, independent of the 7
upstream-test census above: the gemspec/Rakefile wire up RSpec, and it has
0 specs to run. A test target that exists and has nothing registered under
it is a gap the runtime gate does not surface, because `rake test` ==
`test/drive_papers.rb` in this port's `Rakefile`, not `rake spec`.

Upstream test count, port count and gap count are unchanged at **7 upstream
/ 0 ported / 7 gaps**; the `## Extra` count grows from 147 to 163 checks
across 35 named steps, still not parity work per this skill's own rule.
