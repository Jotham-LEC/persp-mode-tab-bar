;;; persp-mode-tab-bar.el --- Show persp-mode workspaces in the tab bar -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jotham Lim Ee Chen

;; Author: Jotham Lim Ee Chen <jotham@cothink.ing>
;; URL: https://github.com/Jotham-LEC/persp-mode-tab-bar
;; Version: 0.1.1
;; Package-Requires: ((emacs "29.1") (persp-mode "2.9.8"))
;; Keywords: convenience, frames

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; persp-mode keeps several workspaces, and shows you which one you are in by
;; echoing the list when you switch.  A message is gone a moment later, so the
;; answer to "where am I?" is always one keystroke away and never on screen.
;;
;; Emacs already has a strip across the top of the frame for exactly this.
;; persp-mode-tab-bar draws the workspaces in it: numbered, the current one
;; picked out, and clickable.
;;
;;     (persp-mode-tab-bar-mode 1)
;;
;; It works with Doom Emacs's `+workspace' commands and with plain persp-mode,
;; detecting which at runtime.  Under Doom it also stops the echoed workspace
;; list, since the tab bar is now saying the same thing permanently.
;;
;; The tab bar is shared ground, so this mode takes only the space it needs.
;; It splices itself into `tab-bar-format' in place of the items that draw the
;; real tabs and leaves every other item where it was, which is what lets
;; packages like tab-bar-echo-area or a global string in the right corner go on
;; working.  It also defines its own two faces rather than restyling the
;; `tab-bar-tab' family, so a theme or a package like vim-tab-bar keeps the
;; look it gave them.  Turning the mode off puts `tab-bar-format' back.

;;; Code:

(require 'cl-lib)
(require 'tab-bar)
(require 'persp-mode)

(declare-function +workspace-list-names "ext:workspaces")
(declare-function +workspace-switch "ext:workspaces")

(defgroup persp-mode-tab-bar nil
  "Show `persp-mode' workspaces in Emacs's tab bar."
  :group 'persp-mode
  :group 'tab-bar
  :link '(url-link :tag "Homepage" "https://github.com/Jotham-LEC/persp-mode-tab-bar"))

(defcustom persp-mode-tab-bar-backend 'auto
  "Which workspace API to read the workspaces from.
`auto' uses Doom Emacs's `+workspace' commands where they exist and
plain `persp-mode' everywhere else.  `doom' and `persp-mode' pin the
choice, which is worth doing if you have Doom's module loaded but do not
want its notion of the workspace list."
  :type '(choice (const :tag "Detect Doom Emacs" auto)
                 (const :tag "Doom Emacs workspaces" doom)
                 (const :tag "Plain persp-mode" persp-mode)))

(defcustom persp-mode-tab-bar-replace
  '(tab-bar-format-tabs tab-bar-format-tabs-groups)
  "The `tab-bar-format' items this mode takes the place of.
These are the items that draw the real tab-bar tabs; left in, they would
put a second row of tabs beside the workspace list.  Everything else in
`tab-bar-format' -- history buttons, separators, the global string,
whatever other packages have added -- stays exactly where it is."
  :type '(repeat function))

(defcustom persp-mode-tab-bar-silence-doom-echo t
  "Whether to stop Doom Emacs echoing the workspace list.
Doom prefixes its workspace messages with the very list the tab bar is
already showing, and `+workspace/display' says nothing else at all.  Off
by setting this to nil; it has no effect outside Doom."
  :type 'boolean)

(defface persp-mode-tab-bar-current '((t :inherit (bold highlight)))
  "Face for the current workspace.
The default composes two stock faces at the point of use rather than
restyling anything, so it follows the theme's accent without a theme
being able to overwrite it the way it can overwrite `:inherit'.")

(defface persp-mode-tab-bar-inactive '((t :inherit (shadow tab-bar-tab-inactive)))
  "Face for a workspace other than the current one.")

(defconst persp-mode-tab-bar--redraw-hooks
  '(persp-activated-functions
    persp-names-cache-changed-functions
    persp-renamed-functions)
  "The `persp-mode' hooks after which the tab bar would draw something else.")

(defvar persp-mode-tab-bar--saved-state nil
  "What the mode changed, as (FORMAT SHOW TAB-BAR-WAS-OFF), or nil.
Nil while the mode is off, so that disabling it twice cannot restore a
`tab-bar-format' the mode has already handed back.")

(defun persp-mode-tab-bar--backend ()
  "Return the workspace API in effect, `doom' or `persp-mode'."
  (pcase persp-mode-tab-bar-backend
    ('auto (if (fboundp '+workspace-list-names) 'doom 'persp-mode))
    (backend backend)))

(defun persp-mode-tab-bar--names ()
  "Return the workspace names, in `persp-mode' order."
  (if (eq (persp-mode-tab-bar--backend) 'doom)
      (+workspace-list-names)
    ;; The nil perspective is every frame's fallback rather than a workspace
    ;; anyone switches to, and Doom's own list drops it too.
    (cl-remove persp-nil-name (persp-names-current-frame-fast-ordered)
               :count 1 :test #'equal)))

(defalias 'persp-mode-tab-bar--get-current
  ;; persp-mode 4.0.0 renamed this and left the old name as an obsolete alias.
  ;; Resolving it once at load time keeps the package quiet, and working, on
  ;; either side of that release.
  (if (fboundp 'persp-get-current) 'persp-get-current 'get-current-persp)
  "Return the current perspective, or nil for the nil perspective.")

(defun persp-mode-tab-bar--current-name ()
  "Return the name of the current workspace."
  ;; What `safe-persp-name' did, written out: 4.0.0 retired it in favour of a
  ;; `persp-name' that takes the nil perspective, and before that `persp-name'
  ;; is the bare struct accessor and cannot.
  (let ((persp (persp-mode-tab-bar--get-current)))
    (if persp (persp-name persp) persp-nil-name)))

(defun persp-mode-tab-bar--switch (name)
  "Switch to the workspace called NAME."
  (if (eq (persp-mode-tab-bar--backend) 'doom)
      (+workspace-switch name)
    (when (persp-get-by-name name)
      (persp-frame-switch name))))

;;;###autoload
(defun persp-mode-tab-bar-format ()
  "Return one tab-bar item per workspace; click one to switch to it."
  (when (bound-and-true-p persp-mode)
    (let ((current (persp-mode-tab-bar--current-name))
          (index 0))
      (mapcar
       (lambda (name)
         (setq index (1+ index))
         ;; `tab-bar-auto-width' shrinks the items keyed `tab-N', `current-tab'
         ;; and `group-N'.  A `workspace-N' key is outside that set, so a
         ;; workspace keeps the width of its own name.
         `(,(intern (format "workspace-%d" index))
           menu-item
           ,(propertize (format " %d %s " index name)
                        'face (if (equal name current)
                                  'persp-mode-tab-bar-current
                                'persp-mode-tab-bar-inactive))
           ,(lambda () (interactive) (persp-mode-tab-bar--switch name))
           :help ,(format "Switch to workspace %s" name)))
       (persp-mode-tab-bar--names)))))

(defun persp-mode-tab-bar-format-fill ()
  "Return an item that stops the last one's face running to the frame edge."
  ;; On GUI frames the final item's face paints the rest of the line, so a
  ;; selected last workspace would bleed its block across the empty space.
  `((persp-mode-tab-bar-fill menu-item ,(propertize " " 'face 'tab-bar) ignore)))

(defun persp-mode-tab-bar--splice (format)
  "Return FORMAT with the workspace list in place of the real tabs.
Items named by `persp-mode-tab-bar-replace' give up their place; if
FORMAT has none, the workspace list goes first instead."
  (let* ((replaced nil)
         (spliced (mapcan (lambda (item)
                            (cond ((not (memq item persp-mode-tab-bar-replace))
                                   (list item))
                                  (replaced nil)
                                  (t (setq replaced t)
                                     (list #'persp-mode-tab-bar-format))))
                          format)))
    (unless replaced
      (push #'persp-mode-tab-bar-format spliced))
    ;; Align-right already closes the run of tabs, and a second closing item
    ;; would push whatever follows it back to the left.
    (if (memq 'tab-bar-format-align-right spliced)
        spliced
      (append spliced (list #'persp-mode-tab-bar-format-fill)))))

(defun persp-mode-tab-bar--redraw (&rest _)
  "Redraw the tab bar on every frame."
  (force-mode-line-update t))

(defun persp-mode-tab-bar--message-body (message &optional type)
  "Format MESSAGE of TYPE the way Doom does, minus the workspace list.
Doom builds every workspace message here, so renames and errors survive
with only their prefix gone."
  (propertize (format "%s" message)
              'face (pcase type
                      ('error 'error)
                      ('warn 'warning)
                      ('success 'success)
                      ('info 'font-lock-comment-face))))

(defun persp-mode-tab-bar--silence-doom (silence)
  "Advise Doom's workspace echo away when SILENCE, and restore it otherwise."
  (when (fboundp '+workspace--message-body)
    (if silence
        (progn
          (advice-add '+workspace--message-body :override
                      #'persp-mode-tab-bar--message-body)
          (advice-add '+workspace/display :override #'ignore))
      (advice-remove '+workspace--message-body #'persp-mode-tab-bar--message-body)
      (advice-remove '+workspace/display #'ignore))))

(defun persp-mode-tab-bar--enable ()
  "Put the workspace list in the tab bar and show the bar."
  (unless persp-mode-tab-bar--saved-state
    (setq persp-mode-tab-bar--saved-state
          (list tab-bar-format tab-bar-show (not (bound-and-true-p tab-bar-mode)))))
  (setq tab-bar-format (persp-mode-tab-bar--splice tab-bar-format))
  ;; A number here hides the bar until that many real tabs exist, and a
  ;; workspace is not a tab, so it would hide a bar with everything to show.
  (when (natnump tab-bar-show)
    (setq tab-bar-show t))
  (dolist (hook persp-mode-tab-bar--redraw-hooks)
    (add-hook hook #'persp-mode-tab-bar--redraw))
  (when (and persp-mode-tab-bar-silence-doom-echo
             (eq (persp-mode-tab-bar--backend) 'doom))
    (persp-mode-tab-bar--silence-doom t))
  (unless (bound-and-true-p tab-bar-mode)
    (tab-bar-mode 1)))

(defun persp-mode-tab-bar--disable ()
  "Hand `tab-bar-format' back the way it was found."
  (dolist (hook persp-mode-tab-bar--redraw-hooks)
    (remove-hook hook #'persp-mode-tab-bar--redraw))
  (persp-mode-tab-bar--silence-doom nil)
  (when persp-mode-tab-bar--saved-state
    (pcase-let ((`(,format ,show ,tab-bar-was-off) persp-mode-tab-bar--saved-state))
      (setq tab-bar-format format
            tab-bar-show show)
      (when tab-bar-was-off
        (tab-bar-mode -1)))
    (setq persp-mode-tab-bar--saved-state nil))
  (force-mode-line-update t))

;;;###autoload
(define-minor-mode persp-mode-tab-bar-mode
  "Draw the `persp-mode' workspaces in Emacs's tab bar.

The workspace list replaces the items of `tab-bar-format' named by
`persp-mode-tab-bar-replace', which are the ones that draw the real
tab-bar tabs.  Everything else in the format is left alone, so other
tab-bar packages keep their place, and turning the mode off restores the
format and `tab-bar-show' as they were.  The tab bar itself is only
turned off again if this mode was what turned it on.

Real tab-bar tabs are unaffected: they are simply not drawn."
  :global t
  :group 'persp-mode-tab-bar
  (if persp-mode-tab-bar-mode
      (persp-mode-tab-bar--enable)
    (persp-mode-tab-bar--disable)))

(provide 'persp-mode-tab-bar)
;;; persp-mode-tab-bar.el ends here
