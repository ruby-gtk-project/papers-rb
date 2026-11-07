# Test parity — papers-rb

| | |
|---|---|
| Upstream | `main` @ `origin/main` (archived 2026-11-07) |
| Port | `ruby` @ `1cf0bfddd` |
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

The round's gate was reported as `drive_ok=true, 131 checks passed, 0
failed, covering 31 components`. Running it directly reproduces that:

```
nix develop --command xvfb-run -a ruby test/drive_papers.rb
...
131 of 131 checks passed
DRIVE OK
```

This is real — the command runs, under the fork's own dev shell and a
virtual display, and all 131 named checks do pass. But it is a **narrow**
gate, and the drive script says so about itself, in its own header comment:

> "since `application.rb` wires almost nothing else into the running window
> yet — \[this script] builds and exercises every other widget and model
> class the port ships \[...] directly, the same way the window would if it
> used them."

Read plainly: 29 of the 31 "components" the gate covers
(`LoaderView`, `PasswordDialog`/`PasswordView`, `ProgressMessageArea`,
`SimpleColorSwatch`, `SidebarPage`, `DocumentModel`, `AnnotationModel`,
`History`, `UndoContext`, `ThumbnailItem`, `SearchResult`, `FileMonitor`,
`Keyring`, `Metadata`, `SignatureImageProcessing`, `SignatureManager`,
`InkTransformation`, `ViewColors`, `ViewCursor`, `CssUtils`,
`PropertiesLicense`, and the application/shortcuts/about dialogs) are
instantiated and poked **directly**, bypassing the main window entirely —
because the main window (`lib/window.rb`), the document view
(`lib/document_view.rb`), and every sidebar/properties/annotation widget
that would actually wire them together **do not exist**
(`.reports/component-inventory.md` §1–6, and `.reports/component-parity.md`).
"131 of 131 checks passed" is therefore not evidence that the app works end
to end; it is evidence that 20-odd backend classes work in isolation, which
is a real and useful signal, but a different and much smaller claim than
"the app's 31 components are integration-tested." A component no check
exercises *through the real window* is unverified at the level a user
experiences the app, regardless of how many unit-style checks exercise its
class directly. This gate passing and the app still having no document
viewer, no sidebar, and five dead keyboard accelerators (see
`component-parity.md`) are not in tension — they are the same fact stated
twice.

## Extra

- `test/drive_papers.rb` + `test/gtk_driver.rb` — 131 checks across 30 named
  steps, driving: application build, window/toolbar/menu construction, the
  shortcuts and about dialogs, settings round-trip to disk, stylesheet
  parsing, and the 20 backend/model classes listed above, each exercised
  directly rather than through the window. None of these were written from
  an upstream test; they are new coverage for the port's own classes and
  are not parity work (per the skill's rule, they stay listed here, outside
  the 0/7 count, and are not double-counted as if they closed any of the
  7 gaps above).

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
