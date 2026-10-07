;;; screenshots.el --- Make the README's images -*- lexical-binding: t; -*-

;;; Commentary:

;; From the top of the repository, in a graphical session, after `make deps':
;;
;;     emacs -Q -l images/screenshots.el
;;
;; It loads persp-mode from .deps, sets up four workspaces with a buffer
;; each, has Emacs write its own frame to PNG (Emacs built with Cairo) as
;; it switches between them, and puts images/demo.gif, images/formats.png
;; and images/customised.png together with ImageMagick's `magick'.  Emacs
;; exits when it is done.  The frame shows on screen while it works; to
;; keep it off the screen, run it under a headless Wayland compositor, such
;; as
;;
;;     WLR_BACKENDS=headless sway
;;
;; with WAYLAND_DISPLAY set to that compositor's socket.

;;; Code:

(require 'cl-lib)
(require 'package)

(defconst screenshots-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "The images directory, where the images are written.")

(defvar screenshots-tmp (make-temp-file "persp-mode-tab-bar-shots-" t)
  "Where the frames are written before they are put together.")

;; persp-mode comes from .deps, as `make deps' installs it: the set for this
;; Emacs if there is one, and otherwise the newest there is, from source,
;; since bytecode from another Emacs need not load in this one.
(let ((deps (expand-file-name "../.deps" screenshots-dir)))
  (setq package-user-dir (expand-file-name emacs-version deps)
        package-quickstart-file (expand-file-name "quickstart.el"
                                                  package-user-dir))
  (package-initialize)
  (unless (locate-library "persp-mode")
    (let ((dir (car (sort (seq-filter #'file-directory-p
                                      (file-expand-wildcards
                                       (expand-file-name "*/persp-mode-*" deps)))
                          (lambda (a b)
                            (string> (file-name-nondirectory a)
                                     (file-name-nondirectory b)))))))
      (unless dir
        (error "No persp-mode under %s; run `make deps' first" deps))
      (add-to-list 'load-path dir)
      (load (expand-file-name "persp-mode.el" dir) nil t))))

(setq load-prefer-newer t)
(add-to-list 'load-path (expand-file-name ".." screenshots-dir))

;; Plain persp-mode lists its nil perspective first; naming it "main" makes
;; it the first workspace.  Nothing is read from or saved to disk.
(setq persp-nil-name "main"
      persp-auto-resume-time -1
      persp-auto-save-opt 0
      persp-save-dir (file-name-as-directory screenshots-tmp))
(require 'persp-mode)
(require 'persp-mode-tab-bar)

(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore
      frame-resize-pixelwise t
      make-backup-files nil
      auto-save-default nil
      create-lockfiles nil
      org-startup-folded nil
      display-time-format "%a %H:%M"
      display-time-default-load-average nil)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode -1)
(load-theme 'modus-operandi t)
(set-face-attribute 'default nil :family "DejaVu Sans Mono" :height 140)

(defun screenshots-export (name)
  "Write the selected frame to NAME.png in a temporary directory.
Return the file name."
  (message nil)
  (redraw-frame)
  (redisplay t)
  (sit-for 0.3)
  (redisplay t)
  (let ((file (expand-file-name (concat name ".png") screenshots-tmp))
        (coding-system-for-write 'binary))
    (with-temp-file file
      (set-buffer-multibyte nil)
      (insert (x-export-frames nil 'png)))
    file))

(defun screenshots-magick (&rest args)
  "Run `magick' with ARGS, signalling if it fails."
  (unless (zerop (apply #'call-process "magick" nil nil nil args))
    (error "Magick failed: %S" args)))

(defun screenshots-framed (file)
  "Return FILE with a thin grey border, as a new file beside it."
  (let ((framed (concat (file-name-sans-extension file) "-framed.png")))
    (screenshots-magick file "-bordercolor" "#c8c8c8" "-border" "1" framed)
    framed))

(defun screenshots-save (name)
  "Export the frame as images/NAME.png, with a border."
  (screenshots-magick (screenshots-framed (screenshots-export name))
                      "-strip" (expand-file-name (concat name ".png")
                                                 screenshots-dir)))

(defvar screenshots-steps nil
  "Steps still to run, each (DELAY . FUNCTION).")

(defun screenshots-run (&rest steps)
  "Run STEPS, each (DELAY . FUNCTION), DELAY seconds after the last.
They run from timers, so that each frame is drawn before the next step."
  (setq screenshots-steps steps)
  (screenshots--next))

(defun screenshots--next ()
  "Run the next of `screenshots-steps' after its delay."
  (when screenshots-steps
    (pcase-let ((`(,delay . ,fn) (pop screenshots-steps)))
      (run-at-time delay nil
                   (lambda ()
                     (condition-case err
                         (funcall fn)
                       (error (message "Screenshot step failed: %S" err)
                              (kill-emacs 2)))
                     (screenshots--next))))))

(defun screenshots-size ()
  "Make the frame 100 columns by 18 lines."
  (set-frame-size nil 100 18))

(defun screenshots-buffer (name mode &rest lines)
  "Return a buffer called NAME in MODE, holding LINES."
  (with-current-buffer (get-buffer-create name)
    (erase-buffer)
    (insert (mapconcat #'identity lines "\n") "\n")
    (funcall mode)
    (set-buffer-modified-p nil)
    (goto-char (point-min))
    (current-buffer)))

(defun screenshots-workspace (name buffer)
  "Switch to workspace NAME, making it if need be, and show BUFFER in it."
  (persp-frame-switch name)
  (delete-other-windows)
  (persp-add-buffer buffer)
  (switch-to-buffer buffer))

(let ((todo (screenshots-buffer
             "todo.org" #'org-mode
             "#+title: This week"
             ""
             "* TODO Ship the job status endpoint"
             "* TODO Tidy the tab-bar config"
             "* DONE Renew the TLS certificate"
             "* TODO Write up the incident notes"))
      (init (screenshots-buffer
             "init.el" #'emacs-lisp-mode
             ";;; init.el --- Workspaces -*- lexical-binding: t; -*-"
             ""
             "(use-package persp-mode"
             "  :ensure t"
             "  :config"
             "  (persp-mode 1))"
             ""
             "(use-package persp-mode-tab-bar"
             "  :vc (:url \"https://github.com/Jotham-LEC/persp-mode-tab-bar\""
             "       :rev :newest)"
             "  :hook (persp-mode . (lambda ()"
             "                        (persp-mode-tab-bar-mode"
             "                         (if persp-mode 1 -1)))))"))
      (server (screenshots-buffer
               "server.py" #'python-mode
               "\"\"\"Tiny status API.\"\"\""
               ""
               "from fastapi import FastAPI, HTTPException"
               ""
               "app = FastAPI(title=\"status\")"
               ""
               "JOBS: dict[str, str] = {}"
               ""
               ""
               "@app.get(\"/health\")"
               "async def health() -> dict[str, str]:"
               "    return {\"status\": \"ok\"}"
               ""
               ""
               "@app.get(\"/jobs/{job_id}\")"
               "async def job(job_id: str) -> dict[str, str]:"
               "    if job_id not in JOBS:"
               "        raise HTTPException(status_code=404)"
               "    return {\"id\": job_id, \"state\": JOBS[job_id]}"))
      (notes (screenshots-buffer
              "notes.org" #'org-mode
              "#+title: Notes"
              ""
              "* Incident, Tuesday"
              "The certificate on the status API expired at 03:12."
              "Renewal ran, but the reload hook was missing."
              ""
              "* Ideas"
              "- Alert a week before any certificate expires."
              "- Put the reload in the renewal job itself."))
      (formats (screenshots-buffer
                "formats.el" #'emacs-lisp-mode
                ";;; Other items in the tab bar -*- lexical-binding: t; -*-"
                ""
                ";; Set before the mode is turned on: the workspaces take"
                ";; the place of `tab-bar-format-tabs', and the rest stays."
                "(setq tab-bar-format"
                "      '(tab-bar-format-history"
                "        tab-bar-format-tabs"
                "        tab-bar-separator"
                "        tab-bar-format-align-right"
                "        tab-bar-format-global))"
                ""
                "(tab-bar-history-mode 1)"
                "(display-time-mode 1)"
                "(persp-mode-tab-bar-mode 1)"))
      (styling (screenshots-buffer
                "styling.el" #'emacs-lisp-mode
                ";;; Restyling the workspace list -*- lexical-binding: t; -*-"
                ""
                "(custom-set-faces"
                " '(persp-mode-tab-bar-current"
                "   ((t :inherit bold :foreground \"#ffffff\" :background \"#6f5bd5\")))"
                " '(persp-mode-tab-bar-inactive"
                "   ((t :foreground \"#8f8f9d\"))))"))
      (demo nil))
  (persp-mode 1)
  (persp-mode-tab-bar-mode 1)
  (screenshots-workspace "emacs-config" init)
  (screenshots-workspace "api-server" server)
  (screenshots-workspace "notes" notes)
  (screenshots-workspace persp-nil-name todo)
  (screenshots-run
   ;; Sized once the tab bar is on, since turning it on can resize the frame.
   (cons 0.5 #'screenshots-size)
   (cons 1 (lambda () (push (screenshots-export "demo-1") demo)))
   (cons 0.2 (lambda () (persp-frame-switch "emacs-config")))
   (cons 0.5 (lambda () (push (screenshots-export "demo-2") demo)))
   (cons 0.2 (lambda () (persp-frame-switch "api-server")))
   (cons 0.5 (lambda () (push (screenshots-export "demo-3") demo)))
   (cons 0.2 (lambda () (persp-frame-switch "notes")))
   (cons 0.5 (lambda () (push (screenshots-export "demo-4") demo)))
   (cons 0.2 (lambda ()
               (pcase-let ((`(,one ,two ,three ,four)
                            (mapcar #'screenshots-framed (reverse demo))))
                 (screenshots-magick "+dither"
                                     "-delay" "220" one "-delay" "220" two
                                     "-delay" "220" three "-delay" "220" four
                                     "-loop" "0" "-layers" "Optimize"
                                     (expand-file-name "demo.gif"
                                                       screenshots-dir)))))
   ;; The tab bar alongside other items, as formats.el sets it up.
   (cons 0.2 (lambda ()
               (persp-frame-switch "emacs-config")
               (switch-to-buffer formats)
               (persp-mode-tab-bar-mode -1)
               (with-current-buffer formats
                 (eval-buffer))))
   (cons 0.5 #'screenshots-size)
   (cons 1 (lambda () (screenshots-save "formats")))
   ;; The README's own snippet, on the default format.
   (cons 0.2 (lambda ()
               (persp-mode-tab-bar-mode -1)
               (display-time-mode -1)
               (tab-bar-history-mode -1)
               (setq tab-bar-format
                     (eval (car (get 'tab-bar-format 'standard-value))))
               (persp-mode-tab-bar-mode 1)
               (switch-to-buffer styling)
               (with-current-buffer styling
                 (eval-buffer))))
   (cons 0.5 #'screenshots-size)
   (cons 1 (lambda () (screenshots-save "customised")))
   (cons 0.2 (lambda ()
               (delete-directory screenshots-tmp t)
               (kill-emacs 0)))))

;;; screenshots.el ends here
