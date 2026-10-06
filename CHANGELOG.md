# Changelog

All notable changes to persp-mode-tab-bar are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Turning the mode off moved items other packages added while it was on.** Every
  added item went in before `tab-bar-format-align-right`, or last, so the menu-bar
  button `add-to-list` puts first ended up at the far right, and a global string
  appended after `tab-bar-format-align-right` lost its place on the right. An added
  item now goes back after the item it followed, or first if it was first.
- **A `tab-bar-format` set with `setopt` or Customize while the mode was on was
  rewritten on the way out**, back into the shape of the format the mode found, with
  a "+" button you had not asked for. A format with real tabs in it and none of the
  mode's items is now handed back as it is.
- **A `tab-bar-format` saved with Customize while the mode was on never drew real
  tabs again.** It names the mode's own items, which turning the mode off left in
  place, so the bar went on listing workspaces with the mode off, and drew nothing at
  all before the package loaded. Turning the mode off now puts the real tabs in their
  place, and the two format functions are autoloaded.

## [0.2.2] — 2026-09-29

### Fixed
- **With a number in `tab-bar-show` and `tab-bar-mode` already on, the bar stayed
  hidden.** One tab is not more than 1, so the bar was hidden, and setting
  `tab-bar-show` to `t`, which is all the mode did, does not redraw it. The mode now
  recomputes the bar's lines when it changes `tab-bar-show`, on the way in and on
  the way out, without calling `tab-bar-mode` and so without rerunning Doom's
  tab-bar hook.
- **Doom's workspace messages kept the list under Doom's usual start-up.** Doom
  defines `+workspace--message-body` only when its first workspace command loads the
  file, and the mode only advised functions already defined. Both are now advised
  whenever Doom is detected, since advice on an undefined function waits for it, and
  `+workspace/display` by a function of the mode's own rather than `ignore`.
- **A replaced item added back while the mode was on came back twice.** A package
  adding the "+" button while the mode was on left two of them in the format the mode
  handed back.
- **Turning the mode off undid a `tab-bar-show` set while it was on.** Hiding the bar
  with `setopt` while the mode was on came undone on the way out, even when the mode
  had never touched `tab-bar-show`. Only a number the mode made `t` goes back now, and
  only while it is still `t`.
- **A `tab-bar-format` that already had the workspace list got a second one.** A
  format saved with Customize while the mode was on names the mode's own items, and
  turning the mode on over it next session put another list in front and another
  fill item at the end.
- **Turning the mode off turned off a tab bar that was already off.** If the mode had
  turned the tab bar on and you then turned it off yourself, turning the mode off
  turned it off again, rerunning `tab-bar-mode-hook`, which Doom hangs its
  per-workspace tab handling off.
- **`persp-mode-tab-bar-silence-doom-echo` set while the mode was on did nothing**
  until the mode was toggled. Setting it with `setopt` or Customize now takes effect
  straight away.
- **The face docstring said the default was not `:inherit`.** It is: the faces
  inherit from `bold` and `highlight`, and from `shadow` and `tab-bar-tab-inactive`.
- **The README said `SPC TAB .` shows Doom's workspace list.** It is
  `+workspace/display`, on `SPC TAB TAB`.
- **The `tab-bar-auto-width` note was missing from the README**, though 0.2.1 said it
  had moved there, and was wrong for Emacs 31, which picks tabs to shrink by key while
  `tab-bar-auto-width-faces` is left at its default. It is in the README now, right
  for 29 to 31, and a test holds the package to it.

### Removed
- **`persp-mode-tab-bar-backend`.** The mode uses Doom's `+workspace` commands when
  they are defined and plain persp-mode otherwise, and there is no longer an option
  to pin either; pinning one could only make the bar disagree with the workspace
  commands in use.
- **`persp-mode-tab-bar-replace` as an option.** It is a constant now, naming the
  `tab-bar-format` items that draw real tabs and the "+" button.
- **The autoload cookie on `persp-mode-tab-bar-format`**, which nothing calls before
  the mode has loaded the package.

### Added
- **README notes on `tab-bar-show` nil**, which keeps the bar and so the list hidden,
  and on `C-TAB` and the mouse wheel over the bar, which still move between the real
  tabs the bar does not draw.
- **`make check`**: the tests byte-compiled like the package, relint, a check that the
  files are indented as `emacs -Q` indents them (`make format` fixes it), and a test
  of every option against its `:type`. CI runs it on Emacs 29.1, 30.1, 31.1 and
  snapshot, and against persp-mode 3.0.8. `CONTRIBUTING.md`, `.dir-locals.el` and
  `.editorconfig`.
- **Tests for what a mutation pass found untested**: turning the tab bar on and back
  off, leaving Doom alone when told to or outside Doom, destructive edits to the
  format, redrawing, the fill item and the click help.

## [0.2.1] — 2026-09-28

### Fixed
- **Turning the mode off threw away other packages' changes to `tab-bar-format`.**
  It put back the format it had saved on the way in, wholesale, so an item another
  package added while the mode was on vanished, and one it removed came back. The mode
  now remembers the format as it left it and, on the way out, keeps what others did:
  an added item goes back in before `tab-bar-format-align-right`, or last without one,
  and a removed item stays out.
- **The README's `:hook` recipe left an empty bar when persp-mode was turned off.**
  Calling the mode from `persp-mode-hook` with no argument turns it on, on the way out
  as well as the way in, and the format item returned nothing without persp-mode.
  Without persp-mode it now draws the real tabs, and the recipe passes `1` or `-1` to
  follow persp-mode both ways.
- **The "+" button stayed next to the workspace list.** `tab-bar-format-add-tab`, in
  Emacs's default format since 28.1, made a real tab the bar did not draw. It is in
  `persp-mode-tab-bar-replace` by default now.
- **`unload-feature` left `tab-bar-format` naming functions that no longer existed.**
  `persp-mode-tab-bar-unload-function` turns the mode off first.
- **The package claimed to work with persp-mode 2.9.8.** It redraws on
  `persp-names-cache-changed-functions`, which arrived in 3.0.8, and against 2.9.8
  the bar went stale when a workspace came or went. `Package-Requires` says 3.0.8.

### Added
- **CI on Emacs snapshot, against persp-mode 3.0.8, and through melpazoid.**
  `PERSP_MODE_DIR` in the Makefile tests against a persp-mode checkout of your
  choosing.
- **An alternatives section in the README**, for people not on persp-mode, and a
  note that turning the tab bar on in Doom also turns on its per-workspace tab save
  and restore.
- **A README note on right-click.** The tab bar's context menu is bound for the whole
  bar and picks its entries by item key, so on a workspace it offers "New tab" and
  "Reopen closed tab". There is no per-item way round it.
- **A demo of the bar in the README.** An animated shot of the workspace list
  following a walk through four sample workspaces.
- **A customising section.** What the two faces default to, why they are compositions
  of stock faces rather than `:inherit`, and how to take them over, with a shot of a
  restyled bar; the three variables; and the `tab-bar-auto-width` note, moved here from
  `Sharing the tab bar`.

### Changed
- **`Sharing the tab bar` is now a paragraph called `Compatibility`.** It took three
  paragraphs to say what fits in one: the mode contributes a format item and leaves the
  rest of the tab bar where it found it.

## [0.2.0] — 2026-09-24

A round of adversarial testing, most of it aimed at the plain persp-mode path that
had only ever been exercised through stubs. Four of the five finds were on that path.

### Fixed
- **The tab bar was empty on plain persp-mode until you made a workspace, and marked
  nothing while you were in the nil perspective.** The nil perspective — `none`, where
  persp-mode starts you and where killing your last workspace puts you back — was
  filtered out of the list, so a fresh persp-mode user saw an empty bar, the current
  workspace went unmarked whenever it was that one, and no item could take you back to
  it. It is a real place and now gets a real item. Doom's own workspace list leaves it
  out and so does this, because Doom never leaves you there.
- **Clicking a workspace that had been killed created a workspace by that name.**
  `persp-get-by-name` answers `persp-not-persp`, not nil, for a name that is gone, so
  the guard on it was no guard at all and `persp-frame-switch` went on to make the
  thing. An item can outlive the workspace it names by a redisplay. Both backends now
  check the name against the list first, which also silences the error Doom's
  `+workspace-switch` raises in the same situation.
- **Turning the mode on while it was already on listed every workspace twice.**
  `define-minor-mode` runs the enable body whenever the mode is switched on, already-on
  included, and a config that both calls the mode and hangs it off `persp-mode-hook`
  does exactly that. The splice happens once now; the hooks and the advice either side
  of it were already idempotent.
- **Advising Doom's echo could define `+workspace/display` in an Emacs that has no
  Doom.** The two advices were behind one `fboundp` check on the other function.

### Changed
- The `tab-bar-auto-width` note said these items escape shrinking because of their
  `workspace-N` keys. They escape it because of their faces: `tab-bar-auto-width`
  selects by face, and `persp-mode-tab-bar-current` and
  `persp-mode-tab-bar-inactive` are not in `tab-bar-auto-width-faces` (`:inherit` does
  not count). Same behaviour, and the README now says how to opt in to shrinking.

## [0.1.1] — 2026-09-24

### Fixed
- **The package would not byte-compile against persp-mode 4.0.** `get-current-persp`
  and `safe-persp-name` became obsolete aliases in that release, which is a warning and
  one day a removal. The current perspective is read through whichever name the
  persp-mode in front of it has, so both sides of 4.0 work, and neither warns.

## [0.1.0] — 2026-09-24

First release, extracted from the author's Doom Emacs configuration where it had been
in daily use.

### Added
- **`persp-mode-tab-bar-mode`** draws the persp-mode workspaces in Emacs's tab bar,
  numbered, with the current one picked out and each one clickable.
- **Two backends**, chosen at runtime and pinnable with `persp-mode-tab-bar-backend`:
  Doom Emacs's `+workspace` commands where they exist, plain persp-mode otherwise.
- **`persp-mode-tab-bar-silence-doom-echo`** (default `t`) drops the workspace list
  Doom prefixes to its messages, and `+workspace/display` with it, since the bar now
  shows the list permanently.
- **`persp-mode-tab-bar-replace`**, the `tab-bar-format` items the workspace list
  stands in for, defaulting to the two that draw the real tabs.
- **Faces `persp-mode-tab-bar-current` and `persp-mode-tab-bar-inactive`**, composed
  from stock faces so the tab bar's own faces are never restyled.

[Unreleased]: https://github.com/Jotham-LEC/persp-mode-tab-bar/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.2.2
[0.2.1]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.2.1
[0.2.0]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.2.0
[0.1.1]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.1.1
[0.1.0]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.1.0
