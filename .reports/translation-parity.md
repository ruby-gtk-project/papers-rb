# Translation parity — papers-rb

| | |
|---|---|
| Upstream | `main` @ `origin/main` (archived 2026-11-07) |
| Port | `ruby` @ `1efab65e2` (re-checked 2026-11-08; no `po/` directory and no gettext dependency added since the last pass — grep below reproduced fresh) |
| Domain | `papers` (unconfirmed — read from `meson project()`; no committed `.pot` to cross-check against, and upstream's `po/papers.pot` is not committed to the tree, only generated at build time) |
| Upstream messages | 533 |
| Ported | 0 |
| Gaps | 533 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 649 across 533 messages (78 reused) |
| Port occurrences | 0 |
| Upstream languages | 102 `.po` files, 38,145 translated, 2,504 untranslated, 317 fuzzy |
| Languages shipped by the port | 0 |
| `msgfmt`/`rmsgfmt` check | not run — no gettext toolchain/dependency in the port at all; nothing to compile |
| Non-English screen check | not run — no catalogue exists to load |

Generated from `scripts/catalogue.rb` (translation-parity skill) run against
an `origin/main` archive and against the `ruby` worktree:

```
ruby .claude/skills/translation-parity/scripts/catalogue.rb <upstream> --role upstream
ruby .claude/skills/translation-parity/scripts/catalogue.rb .          --role port
ruby .claude/skills/translation-parity/scripts/catalogue.rb --compare upstream-catalogue.yaml port-catalogue.yaml
```

`summary.parity: false` — 533 gaps, 0 kind mismatches (nothing to mismatch),
0 of 102 languages shipped, domain unconfirmed.

## The finding

**The port has no `po/` directory, no gettext dependency (`gettext`,
`fast_gettext`, or similar) anywhere in its `Gemfile`/`lib`, and the census
of its source returns zero rows.** `grep -rn "gettext\|_(\s*['\"]" lib/ exe/`
turns up nothing except an unrelated `entry.placeholder_text = 'Password'`
(a GTK widget property named `placeholder_text`, not a gettext marker). Every
user-visible string the port currently shows — "Document Viewer", "Main
Menu", "A Ruby GTK4 and Libadwaita port of the Papers document viewer.",
the shortcuts dialog's section titles, the three app-menu item labels — is a
bare Ruby string literal with no translation marker at all.

This means:

- **Parity is 0/533.** None of upstream's 533 distinct messages have a
  counterpart in the port, because the port extracts no messages whatsoever.
- **102 languages, 38,145 already-translated strings, inherited for free by
  any port that keeps upstream's `po/` and byte-identical msgids, are not
  inherited here.** The port is English-only, full stop, with no
  infrastructure for a translator to even begin contributing to it.
- The handful of strings the port does show (listed above) are not just
  untranslated — they are **not upstream's wording either** in some cases
  (`"Document Viewer"` as `APP_NAME`, vs. upstream's app name "Papers";
  `"Main Menu"` as the tooltip text matches upstream's blueprint literally).
  Where they do match upstream's English, that's not translation parity —
  parity is about the msgid key reaching a catalogue, not about the English
  words looking right.
- This is also, independently, a component-parity finding: because
  `lib/window.rb`, `lib/document_view.rb`, and the five sidebar/properties/
  annotation unit groups do not exist (`.reports/component-parity.md`), the
  roughly 400+ of upstream's 533 messages that live in those files'
  `.blp`/`.rs` pairs (menu items, column headers, dialog titles, error
  strings, tooltips) have **no port site to even be a gap against yet** —
  they are blocked on the component gap, not merely untranslated. Only the
  ~130 messages belonging to `shell/src/application.rs`,
  `pps-shortcuts-dialog.blp`, and the three built-but-orphaned widgets
  (`loader_view`, `password_view`/`password_dialog`,
  `progress_message_area`) are even theoretically reachable by the port's
  current component set, and 0 of those are marked either.

## What was not cross-checked

Per the skill, a committed `.pot` should be preferred over a scan when one
exists; upstream's tree as archived from `origin/main` does not ship a
committed `po/papers.pot` (it's a generated build artifact), so the census
above is from source + `.po` files directly, which is the documented
fallback. `po/POTFILES.in` was read (80 entries) and used to sanity-check
the file list the scanner walked; no `POTFILES.in` completeness check
(`comm -13 POTFILES.in <(census file list)`) was run in this pass — flagged
here as an open item rather than silently skipped, since the skill is
explicit that a file missing from `POTFILES.in` is invisible to translators
even when every other count looks fine.

## Extra

None. The port currently emits zero of its own translatable strings through
any marker, so there is nothing to list as "extra, untranslated" — every
string it shows is simply unmarked plain text, which is the gap recorded
above, not a separate category.

## Round update (2026-11-08, `ruby` @ `2e31575ce`)

Re-checked after `2e31575ce` (`lib/window.rb` landed). No change to this
ledger's substance: `find . -iname 'po' -o -iname '*.po'` returns nothing
under the port tree, `grep -rn "gettext\|_(\|N_(\|n_(" lib/ exe/` returns
zero hits, and `window.rb`'s new user-visible strings — `'Document
Viewer'` (window title, `lib/window.rb:47`), its menu item labels, its
error-page heading — are bare Ruby literals, not gettext calls, exactly
the same defect this ledger already records for every other file. No new
message closes a gap and no new message opens one that wasn't already
open in spirit (window titles/menu labels are covered by the existing
533-message upstream census; the specific strings `window.rb` now builds
are a subset of rows already marked `gap` in this file's tables).

**Still 0/533 messages, 0/102 languages, 0 translated strings shipped.**
The gate's runtime pass (163/163, 34 components) and this ledger's 0/533
are not in tension — the drive script asserts on English literals
throughout (e.g. step `[0]`'s "the window builds and shows the empty
state", step `[9]`'s "the about dialog ... carries upstream's fields"),
so a fully English, fully unlocalised app can and does pass all 163 checks
without any of them exercising a translated string. No check in
`test/drive_papers.rb` sets `LANGUAGE=`/`LC_ALL=` to a non-English locale;
confirmed by `grep -n 'LANGUAGE\|LC_ALL' test/drive_papers.rb test/gtk_driver.rb`
returning nothing. The "non-English screen check" row in this ledger's
header remains **not run**, for the same reason it was not run last
round: there is no catalogue to load.
