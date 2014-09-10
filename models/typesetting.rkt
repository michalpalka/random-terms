#lang racket

(require redex/pict
         slideshow/pict
         "pats.rkt"
         "program.rkt"
         "clp.rkt"
         "disunify-a.rkt"
         "du-typesetting.rkt"
         "../common.rkt")

(provide (all-defined-out))

;; TODO: fix layout

(define (init-lang)
  (with-atomic-rewriter 
   'number "Literal"
   (with-atomic-rewriter 
    'variable-not-otherwise-mentioned "Variable"
    (with-atomic-rewriter
     'id "Identifier"
     (hc-append 
      40
      (render-language pats #:nts '(P D J r π))
      (render-language pats #:nts '(a s C e j))
      (render-language pats #:nts '(p m x f)))))))

(define (lang-pict)
  (with-atomic-rewriter
   'variable-not-otherwise-mentioned "Variable"
   (with-atomic-rewriter
    'number "Literal"
    (with-atomic-rewriter 
     'id "Identifier"
     (htl-append 
      40
      (render-language pats #:nts '(P D J M r c a))
      (render-language pats #:nts '(S C s e d))
      (render-language pats #:nts '(Γ Π Σ Ω π))
      (render-language pats #:nts '(p m x f j)))))))

(define (compile-pict)
  (render-metafunction compile #:contract? #t))

(define (compile-M-pict)
  (render-metafunction compile-M #:contract? #t))

(define (extract-apps-J-pict)
  (render-metafunction extract-apps-J #:contract? #t))

(define (extract-apps-r-pict)
  (render-metafunction extract-apps-r #:contract? #t))

(define (extract-apps-a-pict)
  (render-metafunction extract-apps-a #:contract? #t))

(define (extract-apps-p-pict)
  (render-metafunction extract-apps-p #:contract? #t))

(define (clp-red-pict)
  (render-reduction-relation R #:style 'vertical))

(define (solve-pict)
  (with-all-rewriters
   (render-metafunction solve #:contract? #t)))

(define (solve-cstr-pict)
  (with-compound-rewriter
   'do-subst
   (λ (lws)
     (match lws
       [(list _ _ pi inner-lw _)
        (match inner-lw
          [(lw (list _ inner2-lw ellips _) _ _ _ _ _ _)
           (match inner2-lw
             [(lw (list _ x _ p _) _ _ _ _ _ _)
              (list pi "({" x " → " p "} ...)")])])]))
   (render-metafunction solve-cstr)))

(define (param-elim-pict)
  (with-all-rewriters
   (render-metafunction param-elim #:contract? #t)))

(define (get-lw lw content)
  (let recur ([lw lw])
    (and (lw? lw)
        (match (lw-e lw)
          [(? ((curry equal?) content) _)
           lw]
          [(list lws ...)
           (for/or ([lw lws])
             (recur lw))]
          [(? lw? lw)
                (recur lw)]
          [_ #f]))))
    


(define (big-pict)
  (with-font-params
   (vc-append 
    40
    (lang-pict)
   (vl-append 40
              (vl-append 10
                         (compile-pict)
                         (compile-M-pict))
              (vl-append 10
                         (extract-apps-J-pict)
                         (extract-apps-r-pict)
                         (extract-apps-a-pict)
                         (extract-apps-p-pict))
              (clp-red-pict)
              (solve-cstr-pict)
              (solve-pict)
              (param-elim-pict)))))