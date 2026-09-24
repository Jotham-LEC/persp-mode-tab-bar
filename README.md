# persp-mode-tab-bar

[![CI](https://github.com/Jotham-LEC/persp-mode-tab-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/Jotham-LEC/persp-mode-tab-bar/actions/workflows/ci.yml)
[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3%2B-blue.svg)](https://github.com/Jotham-LEC/persp-mode-tab-bar/blob/main/LICENSE)

> Your [persp-mode](https://github.com/Bad-ptr/persp-mode.el) workspaces, drawn in
> Emacs's own tab bar: numbered, the current one picked out, clickable. Works with
> Doom Emacs's `+workspace` commands and with plain persp-mode.

persp-mode tells you which workspace you are in by echoing the list when you switch,
and a message is gone a moment later. Emacs already has a strip across the top of the
frame for exactly this question, so put the answer there and leave it there.

![Switching workspaces: the tab bar follows](images/demo.gif)

## Install

Not on MELPA yet. With `use-package` and Emacs 30's `:vc`:

```elisp
(use-package persp-mode-tab-bar
  :vc (:url "https://github.com/Jotham-LEC/persp-mode-tab-bar" :rev :newest)
  :hook (persp-mode . persp-mode-tab-bar-mode))
```

Or with [straight.el](https://github.com/radian-software/straight.el):

```elisp
(straight-use-package
 '(persp-mode-tab-bar :type git :host github :repo "Jotham-LEC/persp-mode-tab-bar"))
```

Or Doom, in `packages.el`:

```elisp
(package! persp-mode-tab-bar
  :recipe (:host github :repo "Jotham-LEC/persp-mode-tab-bar"))
```

Emacs 29.1 or newer, and persp-mode.

## Use

```elisp
(persp-mode-tab-bar-mode 1)
```

That is the whole interface. Hanging it off `persp-mode-hook`, as the `use-package`
block above does, is the usual arrangement: the bar appears with the workspaces and
goes away with them.

In Doom, where `:ui workspaces` gives you persp-mode already, the mode detects the
`+workspace` commands and uses them, so the numbering and the order match what
`SPC TAB .` shows you. It also silences Doom's echoed workspace list, since the bar is
now saying the same thing permanently and does not stop saying it; set
`persp-mode-tab-bar-silence-doom-echo` to `nil` if you want both. Doom's `:ui tabs` is
centaur-tabs, which tabs buffers — the two do not overlap.

On plain persp-mode the list includes the nil perspective — `none`, where persp-mode
starts you and where killing your last workspace puts you back. It is a real place, so
it gets a real item you can click. Doom's own workspace list leaves it out, and so does
this, because Doom never leaves you there.

## Customising

Two faces draw the list, and the mode restyles nothing else: a theme's `tab-bar-tab`
colours are left exactly as the theme set them.

| Face | Default | Draws |
| --- | --- | --- |
| `persp-mode-tab-bar-current` | `bold` + `highlight` | the workspace you are in |
| `persp-mode-tab-bar-inactive` | `shadow` + `tab-bar-tab-inactive` | every other workspace |

Both defaults are compositions of stock faces, so the list follows whatever theme you
load without knowing anything about it: the current workspace takes the theme's
highlight, the others its dimmed text over the tab bar's own inactive background. They
compose at the point of use rather than through `:inherit`, which a theme can
overwrite.

To take them over, set them the way you set any other face — `custom-set-faces`, or
`:custom-face` in a `use-package` block, or `M-x customize-face`:

```elisp
(custom-set-faces
 '(persp-mode-tab-bar-current
   ((t :inherit bold :foreground "#ffffff" :background "#6f5bd5")))
 '(persp-mode-tab-bar-inactive
   ((t :foreground "#8f8f9d"))))

(setq tab-bar-separator "  ")
```

![A restyled workspace list](images/customised.png)

The spacing around a name is the tab bar's, not this package's: `tab-bar-separator`
sets what goes between the items, and on a GUI frame a `:box` on either face pads and
outlines them. A terminal draws no boxes, so the shot above widens the gap instead.

Widths are the tab bar's business too. `tab-bar-auto-width` shrinks items by face, and
these two faces are not in `tab-bar-auto-width-faces` (`:inherit` does not count), so a
workspace keeps the width of its name; add them to that list to have long names shrink
to fit.

Three variables, all optional:

| Variable | Default | Does |
| --- | --- | --- |
| `persp-mode-tab-bar-backend` | `auto` | pins the workspace API — `doom` or `persp-mode` — instead of detecting it |
| `persp-mode-tab-bar-replace` | the two tab-drawing items | which `tab-bar-format` items the workspace list stands in for |
| `persp-mode-tab-bar-silence-doom-echo` | `t` | drops Doom's echoed workspace list, which the bar is now showing permanently |

Where the list sits is `tab-bar-format`'s business: the workspace list lands where the
real tabs were, so move `tab-bar-format-tabs` in your own format and the list moves
with it.

## Sharing the tab bar

The tab bar is shared ground, so the mode takes only the space it needs.

It does not assign `tab-bar-format`. It splices itself in where the real tabs were —
`tab-bar-format-tabs` or `tab-bar-format-tabs-groups`, which would otherwise draw a
second row of tabs beside the workspace list — and leaves every other item exactly
where it found it. History buttons, separators, `tab-bar-format-global`, the items
[tab-bar-echo-area](https://github.com/fritzgrabo/tab-bar-echo-area) or
[tab-bar-notch](https://github.com/jdtsmith/tab-bar-notch) add: all still there, still
in order. Turning the mode off restores the list you had, and `tab-bar-show` with it.

It defines two faces of its own and restyles nothing, so a theme's `tab-bar-tab` colours
and packages like [vim-tab-bar](https://github.com/jamescherti/vim-tab-bar.el) are
untouched. Its item keys are `workspace-N`, which collide with none of Emacs's own
`tab-N`, `group-N` or `current-tab`.

Real tab-bar tabs keep working. They are simply not drawn, which means Doom's
per-workspace tab sets survive untouched: this package contributes a format item, not a
tab.

## Contributing

It is a small package and a personal one. Bug reports and pull requests are welcome.

```sh
make deps                # persp-mode and package-lint, into ./.deps
make compile lint test   # byte-compile clean, checkdoc, package-lint, ERT
```

CI runs the same on Emacs 29 and 30.

## License

GPL-3.0-or-later.
