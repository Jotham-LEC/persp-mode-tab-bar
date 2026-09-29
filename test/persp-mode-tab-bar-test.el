;;; persp-mode-tab-bar-test.el --- Tests for persp-mode-tab-bar -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with `make test'.  The workspace backend is stubbed throughout: what is
;; under test is what this package puts in `tab-bar-format' and takes out
;; again, not persp-mode's own bookkeeping.

;;; Code:

(require 'cl-lib)
(require 'cus-edit)
(require 'ert)
(require 'persp-mode-tab-bar)

(defmacro persp-mode-tab-bar-test--with-workspaces (names current &rest body)
  "Run BODY with the backend reporting workspaces NAMES and CURRENT."
  (declare (indent 2))
  `(cl-letf (((symbol-function 'persp-mode-tab-bar--names) (lambda () ,names))
             ((symbol-function 'persp-mode-tab-bar--current-name) (lambda () ,current)))
     (let ((persp-mode t))
       ,@body)))


;;; The format function

(ert-deftest persp-mode-tab-bar-format-numbers-every-workspace ()
  (persp-mode-tab-bar-test--with-workspaces '("main" "docs") "main"
    (let ((items (persp-mode-tab-bar-format)))
      (should (equal (mapcar #'car items) '(workspace-1 workspace-2)))
      (should (equal (mapcar (lambda (item) (substring-no-properties (nth 2 item))) items)
                     '(" 1 main " " 2 docs "))))))

(ert-deftest persp-mode-tab-bar-format-marks-only-the-current-workspace ()
  (persp-mode-tab-bar-test--with-workspaces '("main" "docs") "docs"
    (should (equal (mapcar (lambda (item) (get-text-property 0 'face (nth 2 item)))
                           (persp-mode-tab-bar-format))
                   '(persp-mode-tab-bar-inactive persp-mode-tab-bar-current)))))

(ert-deftest persp-mode-tab-bar-format-switches-to-the-workspace-clicked ()
  (let (switched)
    (cl-letf (((symbol-function 'persp-mode-tab-bar--switch)
               (lambda (name) (setq switched name))))
      (persp-mode-tab-bar-test--with-workspaces '("main" "docs") "main"
        (funcall (nth 3 (nth 1 (persp-mode-tab-bar-format))))))
    (should (equal switched "docs"))))

(ert-deftest persp-mode-tab-bar-format-draws-the-real-tabs-without-persp-mode ()
  ;; With the mode hung off `persp-mode-hook', turning persp-mode off leaves
  ;; the mode on, and an empty list here would leave an empty bar.
  (let ((persp-mode nil))
    (should (tab-bar-format-tabs))
    (should (equal (persp-mode-tab-bar-format) (tab-bar-format-tabs)))))

(ert-deftest persp-mode-tab-bar-format-keeps-the-width-of-each-name ()
  ;; As the README says: `tab-bar-auto-width' leaves these items alone unless
  ;; their faces are added to `tab-bar-auto-width-faces'.
  (persp-mode-tab-bar-test--with-workspaces '("main" "docs") "main"
    (let ((names (lambda (items)
                   (mapcar (lambda (item) (substring-no-properties (nth 2 item)))
                           items)))
          (tab-bar--auto-width-hash nil))
      (should (equal (funcall names (tab-bar-auto-width (persp-mode-tab-bar-format)))
                     '(" 1 main " " 2 docs ")))
      (let ((tab-bar-auto-width-faces (append '(persp-mode-tab-bar-current
                                                persp-mode-tab-bar-inactive)
                                              tab-bar-auto-width-faces)))
        (should-not (equal (funcall names
                                    (tab-bar-auto-width (persp-mode-tab-bar-format)))
                           '(" 1 main " " 2 docs ")))))))


(ert-deftest persp-mode-tab-bar-format-says-where-a-click-goes ()
  (persp-mode-tab-bar-test--with-workspaces '("main" "docs") "main"
    (should (equal (plist-get (nthcdr 4 (nth 1 (persp-mode-tab-bar-format))) :help)
                   "Switch to workspace docs"))))

(ert-deftest persp-mode-tab-bar-format-fill-is-a-space-in-the-bar-s-own-face ()
  ;; Anything else and the last workspace's face runs on to the frame edge.
  (let ((items (persp-mode-tab-bar-format-fill)))
    (should (= (length items) 1))
    (should (equal-including-properties (nth 2 (car items))
                                        (propertize " " 'face 'tab-bar)))))

;;; Splicing into `tab-bar-format'

(ert-deftest persp-mode-tab-bar-splice-takes-the-place-of-the-real-tabs ()
  (should (equal (persp-mode-tab-bar--splice
                  '(tab-bar-format-history
                    tab-bar-format-tabs
                    tab-bar-format-align-right
                    tab-bar-format-global))
                 '(tab-bar-format-history
                   persp-mode-tab-bar-format
                   tab-bar-format-align-right
                   tab-bar-format-global))))

(ert-deftest persp-mode-tab-bar-splice-drops-the-new-tab-button-from-the-emacs-default ()
  ;; The "+" makes a real tab, which the bar would then not draw.
  (should (equal (persp-mode-tab-bar--splice
                  '(tab-bar-format-history
                    tab-bar-format-tabs
                    tab-bar-separator
                    tab-bar-format-add-tab))
                 '(tab-bar-format-history
                   persp-mode-tab-bar-format
                   tab-bar-separator
                   persp-mode-tab-bar-format-fill))))

(ert-deftest persp-mode-tab-bar-splice-fills-when-nothing-aligns-right ()
  (should (equal (persp-mode-tab-bar--splice '(tab-bar-format-tabs))
                 '(persp-mode-tab-bar-format persp-mode-tab-bar-format-fill))))

(ert-deftest persp-mode-tab-bar-splice-replaces-the-grouped-tabs-too ()
  (should (equal (persp-mode-tab-bar--splice '(tab-bar-format-tabs-groups))
                 '(persp-mode-tab-bar-format persp-mode-tab-bar-format-fill))))

(ert-deftest persp-mode-tab-bar-splice-leaves-one-workspace-list-only ()
  (should (equal (persp-mode-tab-bar--splice
                  '(tab-bar-format-tabs tab-bar-format-tabs-groups))
                 '(persp-mode-tab-bar-format persp-mode-tab-bar-format-fill))))

(ert-deftest persp-mode-tab-bar-splice-goes-first-when-there-are-no-real-tabs ()
  (should (equal (persp-mode-tab-bar--splice '(tab-bar-format-global))
                 '(persp-mode-tab-bar-format
                   tab-bar-format-global
                   persp-mode-tab-bar-format-fill))))


;;; Enabling and disabling

(defmacro persp-mode-tab-bar-test--with-tab-bar (&rest body)
  "Run BODY with the tab bar's own state saved and restored around it."
  (declare (indent 0))
  `(let ((tab-bar-format (copy-sequence tab-bar-format))
         (tab-bar-show tab-bar-show)
         (persp-mode-tab-bar--saved-state nil)
         (persp-mode-tab-bar-mode nil))
     (cl-letf (((symbol-function 'tab-bar-mode) #'ignore))
       (unwind-protect (progn ,@body)
         (dolist (hook persp-mode-tab-bar--redraw-hooks)
           (remove-hook hook #'persp-mode-tab-bar--redraw))))))

(ert-deftest persp-mode-tab-bar-enabling-and-disabling-round-trips-the-format ()
  (persp-mode-tab-bar-test--with-tab-bar
    (let ((before tab-bar-format))
      (persp-mode-tab-bar-mode 1)
      (should (memq 'persp-mode-tab-bar-format tab-bar-format))
      (persp-mode-tab-bar-mode -1)
      ;; The very list that was there, not a copy that merely looks like it.
      (should (eq tab-bar-format before)))))

(ert-deftest persp-mode-tab-bar-enabling-shows-a-bar-hidden-below-a-tab-count ()
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-show 1)
    (persp-mode-tab-bar-mode 1)
    (should (eq tab-bar-show t))
    (persp-mode-tab-bar-mode -1)
    (should (eq tab-bar-show 1))))

(ert-deftest persp-mode-tab-bar-enabling-leaves-a-boolean-tab-bar-show-alone ()
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-show nil)
    (persp-mode-tab-bar-mode 1)
    (should (eq tab-bar-show nil))))

(defmacro persp-mode-tab-bar-test--with-real-tab-bar (runs &rest body)
  "Run BODY with the real `tab-bar-mode', counting its hook's runs in RUNS."
  (declare (indent 1))
  (let ((was-on (make-symbol "was-on"))
        (count (make-symbol "count")))
    `(let* ((tab-bar-format (copy-sequence tab-bar-format))
            (tab-bar-show tab-bar-show)
            (default-frame-alist default-frame-alist)
            (persp-mode-tab-bar--saved-state nil)
            (persp-mode-tab-bar-mode nil)
            (,was-on tab-bar-mode)
            (,runs 0)
            (,count (lambda () (setq ,runs (1+ ,runs)))))
       (unwind-protect
           (progn
             (add-hook 'tab-bar-mode-hook ,count)
             ,@body)
         (remove-hook 'tab-bar-mode-hook ,count)
         (dolist (hook persp-mode-tab-bar--redraw-hooks)
           (remove-hook hook #'persp-mode-tab-bar--redraw))
         (tab-bar-mode (if ,was-on 1 -1))))))

(ert-deftest persp-mode-tab-bar-enabling-draws-a-bar-a-tab-count-had-hidden ()
  (persp-mode-tab-bar-test--with-real-tab-bar runs
    (setq tab-bar-show 1)
    (tab-bar-mode 1)
    ;; One tab, so `tab-bar-show' has the bar hidden.
    (should (eq (frame-parameter nil 'tab-bar-lines) 0))
    (setq runs 0)
    (persp-mode-tab-bar-mode 1)
    (should (eq (frame-parameter nil 'tab-bar-lines) 1))
    (persp-mode-tab-bar-mode -1)
    (should (eq (frame-parameter nil 'tab-bar-lines) 0))
    ;; Doom hangs its per-workspace tab handling off this hook.
    (should (= runs 0))))

(ert-deftest persp-mode-tab-bar-turns-the-tab-bar-off-only-if-it-turned-it-on ()
  (persp-mode-tab-bar-test--with-real-tab-bar runs
    (tab-bar-mode -1)
    (persp-mode-tab-bar-mode 1)
    (should tab-bar-mode)
    (persp-mode-tab-bar-mode -1)
    (should-not tab-bar-mode)
    (tab-bar-mode 1)
    (persp-mode-tab-bar-mode 1)
    (persp-mode-tab-bar-mode -1)
    (should tab-bar-mode)))

(ert-deftest persp-mode-tab-bar-enabling-adds-the-redraw-hooks ()
  (persp-mode-tab-bar-test--with-tab-bar
    (persp-mode-tab-bar-mode 1)
    (should (cl-every (lambda (hook)
                        (memq #'persp-mode-tab-bar--redraw (symbol-value hook)))
                      persp-mode-tab-bar--redraw-hooks))
    (persp-mode-tab-bar-mode -1)
    (should (cl-notany (lambda (hook)
                         (memq #'persp-mode-tab-bar--redraw (symbol-value hook)))
                       persp-mode-tab-bar--redraw-hooks))))

(ert-deftest persp-mode-tab-bar-enabling-twice-splices-once ()
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-tabs))
    (persp-mode-tab-bar-mode 1)
    (persp-mode-tab-bar-mode 1)
    (should (equal tab-bar-format
                   '(persp-mode-tab-bar-format persp-mode-tab-bar-format-fill)))))

(ert-deftest persp-mode-tab-bar-disabling-twice-restores-once ()
  (persp-mode-tab-bar-test--with-tab-bar
    (persp-mode-tab-bar-mode 1)
    (persp-mode-tab-bar-mode -1)
    (let ((restored tab-bar-format))
      (persp-mode-tab-bar-mode -1)
      (should (eq tab-bar-format restored)))))


;; Other packages go on editing `tab-bar-format' while the mode is on, and
;; turning it off must not undo their work along with ours.

(ert-deftest persp-mode-tab-bar-disabling-keeps-an-item-added-while-on ()
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-history 'tab-bar-format-tabs
                               'tab-bar-format-align-right 'tab-bar-format-global))
    (persp-mode-tab-bar-mode 1)
    (add-to-list 'tab-bar-format 'foreign-item t)
    (persp-mode-tab-bar-mode -1)
    (should (equal tab-bar-format
                   '(tab-bar-format-history
                     tab-bar-format-tabs
                     foreign-item
                     tab-bar-format-align-right
                     tab-bar-format-global)))))

(ert-deftest persp-mode-tab-bar-disabling-appends-an-added-item-without-align-right ()
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-history 'tab-bar-format-tabs))
    (persp-mode-tab-bar-mode 1)
    (push 'foreign-item tab-bar-format)
    (persp-mode-tab-bar-mode -1)
    (should (equal tab-bar-format
                   '(tab-bar-format-history tab-bar-format-tabs foreign-item)))))

(ert-deftest persp-mode-tab-bar-disabling-keeps-an-item-removed-while-on-removed ()
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-history 'tab-bar-format-tabs
                               'tab-bar-format-align-right 'tab-bar-format-global))
    (persp-mode-tab-bar-mode 1)
    (setq tab-bar-format (remq 'tab-bar-format-global tab-bar-format))
    (persp-mode-tab-bar-mode -1)
    (should (equal tab-bar-format
                   '(tab-bar-format-history
                     tab-bar-format-tabs
                     tab-bar-format-align-right)))))

(ert-deftest persp-mode-tab-bar-disabling-hands-back-a-replaced-item-added-again-once ()
  ;; The "+" is gone while the mode is on, so a package that wants it adds it
  ;; back; the format the mode hands back has it already.
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-history 'tab-bar-format-tabs
                               'tab-bar-separator 'tab-bar-format-add-tab))
    (persp-mode-tab-bar-mode 1)
    (add-to-list 'tab-bar-format 'tab-bar-format-add-tab t)
    (persp-mode-tab-bar-mode -1)
    (should (equal tab-bar-format
                   '(tab-bar-format-history
                     tab-bar-format-tabs
                     tab-bar-separator
                     tab-bar-format-add-tab)))))

(ert-deftest persp-mode-tab-bar-disabling-keeps-an-item-appended-in-place ()
  ;; `nconc' and the like change the list the mode left rather than making a
  ;; new one, so the mode's record of that list must be a copy.
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-history 'tab-bar-format-tabs))
    (persp-mode-tab-bar-mode 1)
    (nconc tab-bar-format (list 'foreign-item))
    (persp-mode-tab-bar-mode -1)
    (should (equal tab-bar-format
                   '(tab-bar-format-history
                     tab-bar-format-tabs
                     foreign-item)))))

(ert-deftest persp-mode-tab-bar-disabling-after-others-drop-the-workspace-list ()
  ;; The mode's own items are no concern of the format it hands back, whether
  ;; others kept them or not.
  (persp-mode-tab-bar-test--with-tab-bar
    (setq tab-bar-format (list 'tab-bar-format-history 'tab-bar-format-tabs))
    (persp-mode-tab-bar-mode 1)
    (setq tab-bar-format (remq 'persp-mode-tab-bar-format tab-bar-format))
    (persp-mode-tab-bar-mode -1)
    (should (equal tab-bar-format
                   '(tab-bar-format-history
                     tab-bar-format-tabs)))))

;;; Unloading

(defun persp-mode-tab-bar-test--ours-p (item)
  "Return non-nil if ITEM is a symbol this package defines."
  (and (symbolp item)
       (string-prefix-p "persp-mode-tab-bar" (symbol-name item))))

(ert-deftest persp-mode-tab-bar-unloading-leaves-nothing-behind ()
  (let ((format tab-bar-format)
        (show tab-bar-show)
        (hooks '(persp-activated-functions
                 persp-names-cache-changed-functions
                 persp-renamed-functions)))
    (unwind-protect
        (cl-letf (((symbol-function 'tab-bar-mode) #'ignore))
          (persp-mode-tab-bar-mode 1)
          (unload-feature 'persp-mode-tab-bar t)
          ;; A symbol left in the format is a void function on every redraw.
          (should-not (seq-some #'persp-mode-tab-bar-test--ours-p tab-bar-format))
          (dolist (hook hooks)
            (should-not (seq-some #'persp-mode-tab-bar-test--ours-p
                                  (symbol-value hook)))))
      (setq tab-bar-format format
            tab-bar-show show)
      (require 'persp-mode-tab-bar))))

;;; Options

(ert-deftest persp-mode-tab-bar-options-match-their-types ()
  ;; Customize will not edit a value its `:type' does not match.
  (let ((options nil)
        (mismatched nil))
    (mapatoms (lambda (symbol)
                (when (and (custom-variable-p symbol)
                           (string-prefix-p "persp-mode-tab-bar-"
                                            (symbol-name symbol)))
                  (push symbol options))))
    (should options)
    (dolist (option options)
      (unless (widget-apply (widget-convert (get option 'custom-type))
                            :match (default-value option))
        (push option mismatched)))
    (should-not mismatched)))

;;; persp-mode's hooks

(ert-deftest persp-mode-tab-bar-redraws-on-hooks-persp-mode-defines ()
  ;; `add-hook' on a hook nobody defines makes the variable and never runs it,
  ;; so an older persp-mode would leave the bar stale without a word.  Only a
  ;; `defcustom' leaves a standard value behind; `add-hook' does not.
  (dolist (hook persp-mode-tab-bar--redraw-hooks)
    (should (get hook 'standard-value))))

;;; Doom

(ert-deftest persp-mode-tab-bar-detects-doom ()
  (cl-letf (((symbol-function '+workspace-list-names) (lambda () '("main"))))
    (should (persp-mode-tab-bar--doom-p)))
  (should-not (persp-mode-tab-bar--doom-p)))

(ert-deftest persp-mode-tab-bar-has-no-backend-option ()
  ;; Pinning a backend could only make the bar disagree with the workspace
  ;; commands actually in use, so detection is all there is.
  (should-not (boundp 'persp-mode-tab-bar-backend))
  (should-not (custom-variable-p 'persp-mode-tab-bar-replace)))

(ert-deftest persp-mode-tab-bar-message-body-drops-the-workspace-list ()
  (let ((formatted (persp-mode-tab-bar--message-body "Renamed '#1'->'docs'" 'success)))
    (should (equal (substring-no-properties formatted) "Renamed '#1'->'docs'"))
    (should (eq (get-text-property 0 'face formatted) 'success))))

(ert-deftest persp-mode-tab-bar-silences-doom-before-doom-defines-the-echo ()
  ;; Doom autoloads `+workspace/display' and not `+workspace--message-body',
  ;; so the mode comes on before the second is defined.
  (should-not (fboundp '+workspace--message-body))
  (persp-mode-tab-bar-test--with-tab-bar
    (unwind-protect
        (cl-letf (((symbol-function '+workspace-list-names) (lambda () '("main"))))
          (persp-mode-tab-bar-mode 1)
          (should (advice-member-p #'persp-mode-tab-bar--message-body
                                   '+workspace--message-body))
          (should (advice-member-p #'persp-mode-tab-bar--display
                                   '+workspace/display))
          (persp-mode-tab-bar-mode -1)
          (should-not (advice-member-p #'persp-mode-tab-bar--message-body
                                       '+workspace--message-body))
          (should-not (advice-member-p #'persp-mode-tab-bar--display
                                       '+workspace/display)))
      (persp-mode-tab-bar--silence-doom nil))))

(ert-deftest persp-mode-tab-bar-leaves-doom-s-echo-alone-when-told-to ()
  (persp-mode-tab-bar-test--with-tab-bar
    (unwind-protect
        (cl-letf (((symbol-function '+workspace-list-names) (lambda () '("main"))))
          (let ((persp-mode-tab-bar-silence-doom-echo nil))
            (persp-mode-tab-bar-mode 1)
            (should-not (advice-member-p #'persp-mode-tab-bar--message-body
                                         '+workspace--message-body))
            (should-not (advice-member-p #'persp-mode-tab-bar--display
                                         '+workspace/display))))
      (persp-mode-tab-bar--silence-doom nil))))

(ert-deftest persp-mode-tab-bar-advises-nothing-outside-doom ()
  (persp-mode-tab-bar-test--with-tab-bar
    (unwind-protect
        (progn
          (persp-mode-tab-bar-mode 1)
          (should-not (advice-member-p #'persp-mode-tab-bar--message-body
                                       '+workspace--message-body))
          (should-not (advice-member-p #'persp-mode-tab-bar--display
                                       '+workspace/display)))
      (persp-mode-tab-bar--silence-doom nil))))


;;; Against a real persp-mode

(defmacro persp-mode-tab-bar-test--with-persp-mode (&rest body)
  "Run BODY with persp-mode on, in a throwaway state directory."
  (declare (indent 0))
  `(let ((persp-auto-resume-time -1)
         (persp-auto-save-opt 0)
         (persp-save-dir (make-temp-file "persp-mode-tab-bar-test" t)))
     (unwind-protect
         (progn (persp-mode 1) ,@body)
       (persp-mode -1)
       (delete-directory persp-save-dir t))))

(ert-deftest persp-mode-tab-bar-lists-the-nil-perspective ()
  (persp-mode-tab-bar-test--with-persp-mode
    ;; Where plain persp-mode starts you, and so the whole bar at that point.
    (should (equal (persp-mode-tab-bar--names) (list persp-nil-name)))
    (let ((items (persp-mode-tab-bar-format)))
      (should (= (length items) 1))
      (should (eq (get-text-property 0 'face (nth 2 (car items)))
                  'persp-mode-tab-bar-current)))))

(ert-deftest persp-mode-tab-bar-marks-the-current-workspace-for-real ()
  (persp-mode-tab-bar-test--with-persp-mode
    (persp-add-new "work")
    (persp-frame-switch "work")
    (should (equal (persp-mode-tab-bar--current-name) "work"))
    (should (member "work" (persp-mode-tab-bar--names)))))

(ert-deftest persp-mode-tab-bar-switching-to-a-vanished-workspace-creates-nothing ()
  (persp-mode-tab-bar-test--with-persp-mode
    (persp-add-new "work")
    (let ((before (persp-mode-tab-bar--names))
          (current (persp-mode-tab-bar--current-name)))
      (persp-mode-tab-bar--switch "no-such-workspace")
      (should (equal (persp-mode-tab-bar--names) before))
      (should (equal (persp-mode-tab-bar--current-name) current)))))

(ert-deftest persp-mode-tab-bar-switching-to-a-vanished-doom-workspace-is-quiet ()
  ;; Doom's own `+workspace-switch' signals on a name it does not have.
  (let ((called nil))
    (cl-letf (((symbol-function '+workspace-list-names) (lambda () '("#1")))
              ((symbol-function '+workspace-switch)
               (lambda (name)
                 (unless (member name '("#1"))
                   (error "%s is not an available workspace" name))
                 (setq called name))))
      (should-not (persp-mode-tab-bar--switch "gone"))
      (should (null called))
      (persp-mode-tab-bar--switch "#1")
      (should (equal called "#1")))))

(ert-deftest persp-mode-tab-bar-can-switch-back-to-the-nil-perspective ()
  (persp-mode-tab-bar-test--with-persp-mode
    (persp-add-new "work")
    (persp-mode-tab-bar--switch "work")
    (should (equal (persp-mode-tab-bar--current-name) "work"))
    (persp-mode-tab-bar--switch persp-nil-name)
    (should (equal (persp-mode-tab-bar--current-name) persp-nil-name))))

(ert-deftest persp-mode-tab-bar-clicking-an-item-switches-for-real ()
  (persp-mode-tab-bar-test--with-persp-mode
    (persp-add-new "work")
    (persp-add-new "docs")
    (let ((item (seq-find (lambda (i)
                            (equal (substring-no-properties (nth 2 i)) " 3 docs "))
                          (persp-mode-tab-bar-format))))
      (should item)
      (funcall (nth 3 item))
      (should (equal (persp-mode-tab-bar--current-name) "docs")))))

(ert-deftest persp-mode-tab-bar-redraws-after-every-workspace-change ()
  (persp-mode-tab-bar-test--with-persp-mode
    (persp-mode-tab-bar-test--with-tab-bar
      (let* ((redraws 0)
             (count (lambda (&optional all)
                      (when all (setq redraws (1+ redraws))))))
        (persp-mode-tab-bar-mode 1)
        (advice-add 'force-mode-line-update :before count)
        (unwind-protect
            (dolist (change (list (lambda () (persp-add-new "work"))
                                  (lambda () (persp-frame-switch "work"))
                                  (lambda () (persp-rename "job"))
                                  (lambda () (persp-kill "job"))))
              (setq redraws 0)
              (funcall change)
              (should (> redraws 0)))
          (advice-remove 'force-mode-line-update count)
          (persp-mode-tab-bar-mode -1))))))

(ert-deftest persp-mode-tab-bar-disabling-redraws ()
  (persp-mode-tab-bar-test--with-tab-bar
    (let* ((redraws 0)
           (count (lambda (&optional all)
                    (when all (setq redraws (1+ redraws))))))
      (persp-mode-tab-bar-mode 1)
      (advice-add 'force-mode-line-update :before count)
      (unwind-protect
          (persp-mode-tab-bar-mode -1)
        (advice-remove 'force-mode-line-update count))
      (should (> redraws 0)))))

(provide 'persp-mode-tab-bar-test)
;;; persp-mode-tab-bar-test.el ends here
