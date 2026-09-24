;;; persp-mode-tab-bar-test.el --- Tests for persp-mode-tab-bar -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with `make test'.  The workspace backend is stubbed throughout: what is
;; under test is what this package puts in `tab-bar-format' and takes out
;; again, not persp-mode's own bookkeeping.

;;; Code:

(require 'cl-lib)
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

(ert-deftest persp-mode-tab-bar-format-is-empty-without-persp-mode ()
  (let ((persp-mode nil))
    (should (null (persp-mode-tab-bar-format)))))


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

(ert-deftest persp-mode-tab-bar-splice-keeps-the-emacs-default-intact ()
  (should (equal (persp-mode-tab-bar--splice
                  '(tab-bar-format-history tab-bar-format-tabs
                    tab-bar-separator tab-bar-format-add-tab))
                 '(tab-bar-format-history persp-mode-tab-bar-format
                   tab-bar-separator tab-bar-format-add-tab
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


;;; Backend selection

(ert-deftest persp-mode-tab-bar-backend-detects-doom ()
  (let ((persp-mode-tab-bar-backend 'auto))
    (cl-letf (((symbol-function '+workspace-list-names) (lambda () '("main"))))
      (should (eq (persp-mode-tab-bar--backend) 'doom)))
    (should (eq (persp-mode-tab-bar--backend) 'persp-mode))))

(ert-deftest persp-mode-tab-bar-backend-can-be-pinned ()
  (cl-letf (((symbol-function '+workspace-list-names) (lambda () '("main"))))
    (let ((persp-mode-tab-bar-backend 'persp-mode))
      (should (eq (persp-mode-tab-bar--backend) 'persp-mode)))))

(ert-deftest persp-mode-tab-bar-message-body-drops-the-workspace-list ()
  (let ((formatted (persp-mode-tab-bar--message-body "Renamed '#1'->'docs'" 'success)))
    (should (equal (substring-no-properties formatted) "Renamed '#1'->'docs'"))
    (should (eq (get-text-property 0 'face formatted) 'success))))


;;; Against a real persp-mode

(defmacro persp-mode-tab-bar-test--with-persp-mode (&rest body)
  "Run BODY with persp-mode on, in a throwaway state directory."
  (declare (indent 0))
  `(let ((persp-auto-resume-time -1)
         (persp-auto-save-opt 0)
         (persp-save-dir (make-temp-file "persp-mode-tab-bar-test" t))
         (persp-mode-tab-bar-backend 'persp-mode))
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
  (let ((persp-mode-tab-bar-backend 'doom)
        (called nil))
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

(provide 'persp-mode-tab-bar-test)
;;; persp-mode-tab-bar-test.el ends here
