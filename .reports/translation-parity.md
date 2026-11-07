# Translation parity — papers-rb

| | |
|---|---|
| Upstream | `main` @ `origin/main` (archived 2026-11-07) |
| Port | `ruby` @ `1cf0bfddd` |
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
