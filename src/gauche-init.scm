;;;
;;; gauche-init.scm - initialize standard environment
;;;
;;;  Copyright(C) 2000-2001 by Shiro Kawai (shiro@acm.org)
;;;
;;;  Permission to use, copy, modify, distribute this software and
;;;  accompanying documentation for any purpose is hereby granted,
;;;  provided that existing copyright notices are retained in all
;;;  copies and that this notice is included verbatim in all
;;;  distributions.
;;;  This software is provided as is, without express or implied
;;;  warranty.  In no circumstances the author(s) shall be liable
;;;  for any damages arising out of the use of this software.
;;;
;;;  $Id: gauche-init.scm,v 1.13 2001-03-10 07:51:49 shiro Exp $
;;;

(select-module gauche)

;;
;; Some useful aliases
;;

(define CALL/CC call-with-current-continuation)

;;
;; Auxiliary stuff for R5RS
;;

(define (CALL-WITH-VALUES producer consumer)
  (receive vals (producer) (apply consumer vals)))

;;
;; Loading, require and provide
;;

;; Load path needs to be dealt with at the compile time.  this is a
;; hack to do so.   Don't modify *load-path* directly, since it causes
;; weird compiler-evaluator problem.
;; I don't like the current name "add-load-path", though---looks like
;; more a procedure than a compiler syntax---any ideas?
(define-macro (add-load-path path)
  `',(%add-load-path path))

;; Same as above.
(define-macro (require feature)
  `',(%require feature))

;; Preferred way
;;  (use x.y.z) === (require "x/y/z") (import x.y.z)
(define-macro (use module)
  (unless (symbol? module) (error "use: symbol required: ~s" module))
  (let ((path (string-join (string-split (symbol->string module) #\.) "/")))
    `(begin
       (require ,path)
       (import ,module)))
  )

;;
;; Autoload
;;

;; autoload doesn't work for syntactic binding...
(define-macro (AUTOLOAD file . vars)
  (cons 'begin (map (lambda (v) `(define ,v (%make-autoload ',v ,file)))
                    vars)))



