;;;
;;; auxiliary string utilities.  to be autoloaded.
;;;  
;;;   Copyright (c) 2000-2008  Shiro Kawai  <shiro@acm.org>
;;;   
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;   
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;  
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;  
;;;   3. Neither the name of the authors nor the names of its contributors
;;;      may be used to endorse or promote products derived from this
;;;      software without specific prior written permission.
;;;  
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;  
;;;  $Id: stringutil.scm,v 1.5 2008-05-10 13:35:56 shirok Exp $
;;;

(define-module gauche.stringutil
  (export string-split)
  )
(select-module gauche.stringutil)

;; trick to delay loading of srfi-13 until needed
(autoload srfi-13 string-tokenize)

;; Generic string-split
;;   splitter can be a character, a char-set, a string, or a regexp.
(define (string-split string splitter)
  (cond ((char? splitter) (%string-split-by-char string splitter))
        ((and (string? splitter) (= (string-length splitter) 1))
         (%string-split-by-char string (string-ref splitter 0)))
        (else (%string-split string (%string-split-scanner splitter)))
        ))

;; aux fns
(define (%string-split-scanner splitter)

  (define (null-splitter)
    (error "string-split: splitter must not match a null string:" splitter))

  (cond ((string? splitter)
         (when (string=? splitter "") (null-splitter))
         (lambda (s)
           (receive (before after) (string-scan s splitter 'both)
             (if before (values before after) (values s #f)))))
        ((char-set? splitter)
         (%string-split-scanner-each-char
          (cut char-set-contains? splitter <>)))
        ((regexp? splitter)
         (lambda (s)
           (cond ((rxmatch splitter s)
                  => (lambda (m)
                       (let ((before (m 'before))
                             (after  (m 'after)))
                         (when (string=? s after) (null-splitter))
                         (values before after))))
                 (else (values s #f)))))
        (else ;; assume splitter is a predicate
         (%string-split-scanner-each-char splitter))
        ))

(define (%string-split-scanner-each-char pred)
  (define (scan-in p)
    (let ((c (string-pointer-ref p)))
      (cond ((eof-object? c) (values (string-pointer-substring p) #f))
            ((pred c)
             (let1 before (string-pointer-substring p)
               (string-pointer-next! p)
               (scan-out p before)))
            (else (string-pointer-next! p) (scan-in p)))))
  (define (scan-out p before)
    (let ((c (string-pointer-ref p)))
      (cond ((eof-object? c) (values before ""))
            ((pred c) (string-pointer-next! p) (scan-out p before))
            (else (values before (string-pointer-substring p :after #t))))))
  (lambda (s) (scan-in (make-string-pointer s))))

(define (%string-split string scanner)
  (let loop ((s string)
             (r '()))
    (receive (before after) (scanner s)
      (if after
          (loop after (cons before r))
          (reverse! (cons before r))))))

(provide "gauche/stringutil")
