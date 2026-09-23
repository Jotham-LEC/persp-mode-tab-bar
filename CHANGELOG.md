# Changelog

All notable changes to persp-mode-tab-bar are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Jotham-LEC/persp-mode-tab-bar/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.1.1
[0.1.0]: https://github.com/Jotham-LEC/persp-mode-tab-bar/releases/tag/v0.1.0
