;;; pdf-pagelabels.el --- Transient interface for pagelabels.py  -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Grant Rosson

;; Author: Grant Rosson <https://github.com/localauthor>
;; Created: March 1, 2024
;; License: GPL-3.0-or-later
;; Version: 0.1
;; Homepage: https://github.com/localauthor/pdf-pagelabels
;; Package-Requires: ((emacs "24.4") (transient "0.4.0"))

;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation, either version 3 of the License, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License along
;; with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package produces a Transient interface for the Python utility
;; pagelabels.py, which allows users to manipulate PDF page labels.

;; For example, you can label introductory pages in a PDF copy of a book with
;; the appropriate Roman numerals (eg, i-xvii), and label all subsequent
;; book pages with the appropriate page numbers (eg, 1-280).

;; pagelabels.py is found here: https://github.com/lovasoa/pagelabels-py

;; This package presumes that python3 and pagelabels.py are available on your system.


;;; Code:

(require 'transient)

(defvar pdf-pagelabels-command nil)
(defvar pdf-pagelabels-pdf nil)
(defvar pdf-pagelabels-output-file nil)
(defvar pdf-pagelabels-load-file nil)
(defvar pdf-pagelabels-command-history nil)

(transient-define-prefix
  pdf-pagelabels ()
  "Run pagelabels.py."
  :incompatible '(("--delete" "--startpage=")
                  ("--delete" "--firstpagenum=")
                  ("--delete" "--type")
                  ("--delete" "--prefix=")
                  ("--delete" "--update"))

  ["Files"
   (pdf-pagelabels-select-pdf)
   (pdf-pagelabels-output-file)]

  ["Arguments"
   ("d" "Delete labels" "--delete")
   (pdf-pagelabels-load-file)
   ""
   ("s" "Start page" "--startpage=")
   ;;(pdf-pagelabels-type)
   ("t" "Numbering type" "--type="
    :choices ("\"arabic\""
              "\"roman lowercase\""
              "\"roman uppercase\""
              "\"letters lowercase\""
              "\"letters uppercase\""))
   ("f" "First page num" "--firstpagenum=")
   ""
   ("p" "Prefix" "--prefix=")
   ("u" "Update" "--update")]

  [["Commands"
    (pdf-pagelabels-add-to-command)
    (pdf-pagelabels-run-command)]

   ["Reset"
    (pdf-pagelabels-delete-last-command)
    (pdf-pagelabels-edit-command)
    ("C" "Clear command"
     (lambda () (interactive)
       (setq pdf-pagelabels-command nil))
     :transient t)]]

  [:description (lambda () (if pdf-pagelabels-command
                               (format "Current command:\n%s"
                                       pdf-pagelabels-command)
                             "Current command:\nNo command"))
                ""]

  (interactive)
  (transient-setup 'pdf-pagelabels)
  (transient-bind-q-to-quit)
  (setq pdf-pagelabels-load-file nil))


;;; select files

(transient-define-suffix pdf-pagelabels-select-pdf ()
  "Select pdf."
  :transient t
  :key "P"
  :description (lambda ()
                 (if pdf-pagelabels-pdf
                     (format "PDF:    %s" pdf-pagelabels-pdf)
                   "PDF: None set"))
  (interactive)
  (setq pdf-pagelabels-pdf (read-file-name "File: "))
  (setq pdf-pagelabels-command nil))

(transient-define-suffix pdf-pagelabels-load-file (load)
  "Load file."
  :transient t
  :key "l"
  :description (lambda () (if pdf-pagelabels-load-file
                              (format "Load File: %s" pdf-pagelabels-load-file)
                            "Load File: None set"))
  (interactive "fFile: ")
  (setq pdf-pagelabels-load-file
        (if (string= load "")
            nil
          load)))

(transient-define-suffix pdf-pagelabels-output-file ()
  "Output file."
  :transient t
  :key "O"
  :description (lambda ()
                 (if pdf-pagelabels-output-file
                     (format "Output: %s" (string-trim-left pdf-pagelabels-output-file "-o "))
                   "Output: overwrite original"))
  (interactive)
  (let* ((output (read-file-name "Filename: "
                                 (file-name-directory pdf-pagelabels-pdf))))
    (setq pdf-pagelabels-output-file
          (if (string= output "")
              nil
            (concat "-o " output)))))


;;; arguments

;; (transient-define-argument pdf-pagelabels-type ()
;;   :description "Numbering type"
;;   :key "t"
;;   :class 'transient-switches
;;   :argument-format "--type \"%s\""
;;   :argument-regexp "\\.*"
;;   :choices '("arabic" "roman lowercase" "roman uppercase" "letters lowercase" "letters uppercase"))


;;; commands

(transient-define-suffix pdf-pagelabels-run-command (args)
  "Run pagelabels-py."
  :key "R"
  :description "Run command"
  (interactive (list (transient-args transient-current-command)))
  (when args
    (pdf-pagelabels-add-to-command args))
  (shell-command pdf-pagelabels-command))

(transient-define-suffix pdf-pagelabels-add-to-command (args)
  "Add to command."
  :transient t
  :key "RET"
  :description "Add to command"
  (interactive (list (transient-args transient-current-command)))
  (unless args
    (error "No args set"))
  (unless pdf-pagelabels-pdf
    (error "No PDF set"))
  (pdf-pagelabels-concat-command)
  (transient-reset))

(defun pdf-pagelabels-concat-command ()
  "Produce new command."
  (let* ((args (transient-args transient-current-command))
         (command
          (concat
           "python3 -m pagelabels "
           (string-join args " ") " "
           (if (and pdf-pagelabels-command
                    pdf-pagelabels-output-file)
               (string-trim-left pdf-pagelabels-output-file "-o ")
             (concat
              (unless
                  (transient-arg-value "--delete" args)
                pdf-pagelabels-output-file)
              (format "\"%s\"" (expand-file-name pdf-pagelabels-pdf))))
           "\n")))
    (setq pdf-pagelabels-command (concat pdf-pagelabels-command command))
    (add-to-list 'pdf-pagelabels-command-history command)))

(transient-define-suffix pdf-pagelabels-delete-last-command ()
  "Delete last command."
  :key "D"
  :transient t
  :description "Delete last command"
  (interactive)
  (when pdf-pagelabels-command
    (setq pdf-pagelabels-command
          (string-trim-right
           pdf-pagelabels-command "python3.*\n")))
  (when (string= "" pdf-pagelabels-command)
    (setq pdf-pagelabels-command nil)))

(transient-define-suffix pdf-pagelabels-edit-command ()
  "Edit command manually."
  :key "E"
  :transient t
  :description "Edit command manually"
  (interactive)
  (setq pdf-pagelabels-command
        (read-from-minibuffer
         "Command:\n" pdf-pagelabels-command
         nil nil 'pdf-pagelabels-command-history)))


(provide 'pdf-pagelabels)

;;; pdf-pagelabels.el ends here
