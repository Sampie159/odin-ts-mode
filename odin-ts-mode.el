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

(defcustom odin-ts-mode-module-path-face '@font-lock-constant-face
  "The face to use for highlighting module paths in `odin-ts-mode`."
  :version "29.1"
  :type 'symbol
  :group 'odin-ts)

(defcustom odin-ts-mode-assignment-face '@font-lock-variable-name-face
  "The face to use for highlighting assignments in `odin-ts-mode`."
  :version "29.1"
  :type 'symbol
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

(defconst odin-ts-mode--builtins ;; also stolen
  '("len" "cap"
    "typeid_of" "type_info_of"
    "swizzle" "complex" "real" "imag" "quaternion" "conj"
    "jmag" "kmag"
    "min" "max" "abs" "clamp"
    "expand_to_tuple"

    "init_global_temporary_allocator"
    "copy" "pop" "unordered_remove" "ordered_remove" "clear" "reserve"
    "resize" "new" "new_clone" "free" "free_all" "delete" "make"
    "clear_map" "reserve_map" "delete_key" "append_elem" "append_elems"
    "append" "append_string" "clear_dynamic_array" "reserve_dynamic_array"
    "resize_dynamic_array" "incl_elem" "incl_elems" "incl_bit_set"
    "excl_elem" "excl_elems" "excl_bit_set" "incl" "excl" "card"
    "assert" "panic" "unimplemented" "unreachable")
  "Builtins used in the Odin language.")

(defconst odin-ts-mode--keywords ;; stolen
  '("import" "foreign" "package"
    "where" "when" "if" "else" "for" "switch" "in" "notin" "do" "case"
    "break" "continue" "fallthrough" "defer" "return" "proc"
    "struct" "union" "enum" "bit_field" "bit_set" "map" "dynamic"
    "auto_cast" "cast" "transmute" "distinct" "opaque"
    "using" "inline" "no_inline"
    "size_of" "align_of" "offset_of" "type_of"
    "context"
    "macro" "const")
  "Keywords used in the Odin language.")

(defconst odin-ts-mode--constants ;; guess?
  '("nil" "true" "false"
    "ODIN_OS" "ODIN_ARCH" "ODIN_ENDIAN" "ODIN_VENDOR"
    "ODIN_VERSION" "ODIN_ROOT" "ODIN_DEBUG")
  "Constants used in the Odin language.")

(defconst odin-ts-mode--types ;; you already know >:)
  '("bool" "b8" "b16" "b32" "b64"
    "int" "i8" "i16" "i32" "i64"
    "i16le" "i32le" "i64le"
    "i16be" "i32be" "i64be"
    "i128" "u128"
    "i128le" "u128le"
    "i128be" "u128be"
    "uint" "u8" "u16" "u32" "u64"
    "u16le" "u32le" "u64le"
    "u16be" "u32be" "u64be"
    "f16" "f32" "f64"
    "complex64" "complex128"
    "quaternion128" "quaternion256"
    "rune"
    "string" "cstring"
    "uintptr" "rawptr"
    "typeid" "any"
    "byte")
  "Types used in the Odin language.")

(defconst odin-ts-mode--attributes ;; do i have to say anything?
  '("builtin"
    "export"
    "static"
    "deferred_in" "deferred_none" "deferred_out"
    "require_results"
    "default_calling_convention" "link_name" "link_prefix"
    "deprecated" "private" "thread_local")
  "Attributes used in the Odin language.")

(defconst odin-ts-mode--proc-directives ;; :)
  '("#force_inline"
    "#force_no_inline"
    "#optional_ok"
    "#type")
  "Directives that can appear before or after a proc declaration.")

(defconst odin-ts-mode--directives ;; ;)
  (append '("#align" "#packed"
            "#any_int"
            "#raw_union"
            "#no_nil"
            "#complete"
            "#no_alias"
            "#c_vararg"
            "#assert"
            "#file" "#line" "#location" "#procedure" "#caller_location"
            "#load"
            "#defined"
            "#bounds_check" "#no_bounds_check"
            "#partial")
          odin-ts-mode--proc-directives)
  "Directives that are used in the Odin language.")

(defvar odin-ts-mode--font-lock-rules
  (treesit-font-lock-rules
   :language 'odin
   :override t
   :feature 'comment
   '((comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face)

   :language 'odin
   :override t
   :feature 'literal
   '((number) @font-lock-number-face
     (float) @font-lock-number-face
     (character) @font-lock-constant-face)

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
   :feature 'keyword
   `([,@odin-ts-mode--keywords] @font-lock-keyword-face)

   :language 'odin
   :override t
   :feature 'builtin
   `([,@odin-ts-mode--builtins] @font-lock-builtin-face)

   :language 'odin
   :override t
   :feature 'constant
   `([,@odin-ts-mode--constants] @font-lock-constant-face)

   :language 'odin
   :override t
   :feature 'directive
   `([,@odin-ts-mode--proc-directives] @font-lock-builtin-face)

   :language 'odin
   :override t
   :feature 'variable
   '((identifier) @font-lock-variable-use-face
     (package_declaration (identifier) @font-lock-variable-use-face)
     (import_declaration alias: (identifier) @font-lock-variable-use-face)
     (foreign_block (identifier) @font-lock-variable-use-face)
     (using_statement (identifier) @font-lock-variable-use-face))
   )
  "Font lock rules used by `odin-ts-mode`.")

(defvar odin-ts-mode--font-lock-feature-list
  '((comment)
    (keyword string type)
    (builtin attribute escape-sequence literal constant function)
    (type-property operator bracket punctuation variable property))
  "Feature list used by `odin-ts-mode`.")

(defun odin-ts-mode-install-grammar ()
  "Install the tree-sitter grammar used by `odin-ts-mode`."
  (interactive)
  (let ((odin-grammar '((odin "https://github.com/tree-sitter-grammars/tree-sitter-odin"))))
    (if treesit-language-source-alist
        (add-to-list 'treesit-language-source-alist odin-grammar)
        (defvar treesit-language-source-alist odin-grammar))
    (treesit-install-language-grammar 'odin)))

(defun odin-ts-mode-setup ()
  "Setup treesit for `odin-ts-mode`."

  ;; Highlighting
  (setq-local treesit-font-lock-settings odin-ts-mode--font-lock-rules
              treesit-font-lock-feature-list odin-ts-mode--font-lock-feature-list)

  ;; Indentation
  (setq-local electric-indent-chars (append "{}():;," electric-indent-chars))

  (treesit-major-mode-setup))

;;;###autoload
(define-derived-mode odin-ts-mode prog-mode "odin"
  "Major mode for editing odin files, powered by tree-sitter."
  :group 'odin-ts
  :syntax-table odin-ts-mode--syntax-table

  (when (treesit-ready-p 'odin)
    (treesit-parser-create 'odin)
    (odin-ts-mode-setup)))

(when (treesit-ready-p 'odin)
  (add-to-list 'auto-mode-alist '("\\.odin\\'" . odin-ts-mode)))

(provide 'odin-ts-mode)

;;; odin-ts-mode.el ends here
