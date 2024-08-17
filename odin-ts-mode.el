;;; odin-ts-mode.el --- Odin Lang Major Mode for Emacs -*- lexical-binding: t -*-

;; Author: Sampie159
;; URL: https://github.com/Sampie159/odin-ts-mode
;; Keywords: odin languages tree-sitter
;; Version 0.1.0
;; Package-Requires : ((emacs "29.1"))

;;; License:

;; MIT License
;; 
;; Copyright (c) 2024 Sampie159
;; 
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;; 
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.
;; 
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; Powered by Emacs >= 29 and tree-sitter this major mode provides
;; syntax highlighting, indentation and imenu support for Odin.
;; odin-ts-mode is built against the tree-sitter grammar locatated at
;; https://github.com/tree-sitter-grammars/tree-sitter-odin

;; Much of the structure of this code is based on the c3-ts-mode located at
;; https://github.com/c3lang/c3-ts-mode
;; and on odin-mode located at
;; https://github.com/mattt-b/odin-mode

;; Many thanks for Mickey Petersen for his article "Let's Write a Tree-Sitter Major mode"
;; which can be found at https://www.masteringemacs.org/article/lets-write-a-treesitter-major-mode
;; for helping me do this.

;;; Code:

(require 'treesit)

(defgroup odin-ts nil
  "Major mode for editing odin files."
  :prefix "odin-ts-"
  :group 'languages)

(defcustom odin-ts-mode-indent-offset 4
  "Number of spaces for each indentation step in `odin-ts-mode`."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'odin-ts)

(defcustom odin-ts-mode-hook nil
  "Hook run after entering `odin-ts-mode`."
  :version "29.1"
  :type 'symbol
  :group 'odin-ts)

(defconst odin-ts-mode--syntax-table ;; shamelessly stolen directly from odin-mode
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)

    ;; additional symbols
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?` "\"" table)
    (modify-syntax-entry ?: "." table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?^ "." table)
    (modify-syntax-entry ?! "." table)
    (modify-syntax-entry ?$ "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?? "." table)

    ;; Need this for #directive regexes to work correctly
    (modify-syntax-entry ?#   "_" table)

    ;; Modify some syntax entries to allow nested block comments
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23n" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\^m "> b" table)

    table)
  "Syntax table for `odin-ts-mode`.")

(defconst odin-ts-mode--includes
  '("import" "package")
  "Includes used in `odin-ts-mode`.")

(defconst odin-ts-mode--storage-classes
  '("distinct" "dynamic")
  "Storage classes used in `odin-ts-mode`.")

(defconst odin-ts-mode--operators
  '(":=" "=" "+" "-" "*" "/" "%" "%%" ">" ">=" "<" "<=" "==" "!=" "~="
    "|" "~" "&" "&~" "<<" ">>" "||" "&&" "!" "^" ".." "+=" "-=" "*="
    "/=" "%=" "&=" "|=" "^=" "<<=" ">>=" "||=" "&&=" "&~=" "..=" "..<" "?")
  "Operators used in `odin-ts-mode`.")

(defconst odin-ts-mode--keywords
  '("foreign" "or_else"
    "in" "not_in"
    "defer" "return" "proc"
    "struct" "union" "enum" "bit_field" "bit_set" "map"
    "auto_cast" "cast" "transmute"
    "using")
  "Keywords used in the Odin language.")

(defconst odin-ts-mode--conditionals
  '("if" "else" "when" "switch" "case" "where" "break")
  "Conditionals used in `odin-ts-mode`.")

(defconst odin-ts-mode--repeats
  '("for" "do" "continue")
  "Repeats used in `odin-ts-mode`.")

(defvar odin-ts-mode--font-lock-rules
  (treesit-font-lock-rules
   :language 'odin
   :override t
   :feature 'variable
   '((identifier) @font-lock-variable-use-face)

   :language 'odin
   :override t
   :feature 'namespace
   '((package_declaration (identifier) @font-lock-constant-face)
     (import_declaration alias: (identifier) @font-lock-constant-face)
     (foreign_block (identifier) @font-lock-constant-face)
     (using_statement (identifier) @font-lock-constant-face))

   :language 'odin
   :override t
   :feature 'comment
   '([(comment) (block_comment)] @font-lock-comment-face)

   :language 'odin
   :override t
   :feature 'literal
   '((number) @font-lock-number-face
     (float) @font-lock-number-face
     (character) @font-lock-constant-face
     (boolean) @font-lock-constant-face)

   :language 'odin
   :override t
   :feature 'string
   '((string) @font-lock-string-face)

   :language 'odin
   :override t
   :feature 'escape-sequence
   '((escape_sequence) @font-lock-escape-face)

   :language 'odin
   :override t
   :feature 'preproc
   '([(calling_convention) (tag)] @font-lock-preprocessor-face)

   :language 'odin
   :override t
   :feature 'keyword
   `([,@odin-ts-mode--keywords] @font-lock-keyword-face
     [,@odin-ts-mode--includes] @font-lock-keyword-face
     [,@odin-ts-mode--storage-classes] @font-lock-keyword-face
     [,@odin-ts-mode--conditionals (fallthrough_statement)] @font-lock-keyword-face
     [,@odin-ts-mode--repeats] @font-lock-keyword-face)

   :language 'odin
   :override t
   :feature 'function
   '((procedure_declaration (identifier) @font-lock-function-name-face)
     (call_expression function: (identifier) @font-lock-function-call-face)
     (overloaded_procedure_declaration (identifier) @font-lock-function-name-face))

   :language 'odin
   :override t
   :feature 'type
   `((struct_declaration (identifier) @font-lock-type-face)
     (const_declaration (identifier) @font-lock-type-face)
     (type (identifier) @font-lock-type-face)
     (enum_declaration (identifier) @font-lock-type-face)
     (union_declaration (identifier) @font-lock-type-face)
     (bit_field_declaration (identifier) @font-lock-type-face))

   :language 'odin
   :override t
   :feature 'punctuation
   `([,@odin-ts-mode--operators] @font-lock-punctuation-face
     ["{" "}" "(" ")" "[" "]"] @font-lock-punctuation-face
     ["::" "->" "." "," ":" ";"] @font-lock-punctuation-face
     ["@" "$"] @font-lock-punctuation-face)

   :language 'odin
   :override t
   :feature 'error
   '((ERROR) @font-lock-warning-face)
   )
  "Font lock rules used by `odin-ts-mode`.")

(defvar odin-ts-mode--font-lock-feature-list
  '((comment string)
    (keyword type)
    (builtin preproc escape-sequence literal constant function)
    (operator punctuation variable namespace property))
  "Feature list used by `odin-ts-mode`.")

(defvar odin-ts-mode--indent-rules
  `((odin
     ((parent-is "source_file") column-0 0)
     ((node-is "^\\(}\\|]\\|)\\)") parent-bol 0)
     ((parent-is "block") parent-bol odin-ts-mode-indent-offset)
     ((parent-is "switch_case") parent-bol odin-ts-mode-indent-offset)
     ((node-is "switch_case") parent-bol 0)
     ((parent-is "^\\(struct\\|enum\\|union\\|bit_field\\)_declaration") parent-bol odin-ts-mode-indent-offset)
     ((parent-is "parameters") parent-bol odin-ts-mode-indent-offset)
     (no-node parent 0)
     ))
  "Indentation rules for `odin-ts-mode`.")

(defun odin-ts-mode-setup ()
  "Setup treesit for `odin-ts-mode`."

  ;; Highlighting
  (setq-local treesit-font-lock-settings odin-ts-mode--font-lock-rules
              treesit-font-lock-feature-list odin-ts-mode--font-lock-feature-list)

  ;; Indentation
  (setq-local treesit-simple-indent-rules odin-ts-mode--indent-rules
              electric-indent-chars (append "{}():;,=" electric-indent-chars))

  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode odin-ts-mode prog-mode "odin"
  "Major mode for editing odin files, powered by tree-sitter."
  :group 'odin-ts
  :syntax-table odin-ts-mode--syntax-table

  (when (treesit-ready-p 'odin)
    (treesit-parser-create 'odin)
    (odin-ts-mode-setup)))

;;;###autoload
(when (treesit-ready-p 'odin)
  (add-to-list 'auto-mode-alist '("\\.odin\\'" . odin-ts-mode)))

(provide 'odin-ts-mode)

;;; odin-ts-mode.el ends here
