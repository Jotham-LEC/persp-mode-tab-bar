# Changelog

All notable changes to persp-mode-tab-bar are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Jotham-LEC/persp-mode-tab-bar/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.2.0
[0.1.1]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.1.1
[0.1.0]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.1.0
