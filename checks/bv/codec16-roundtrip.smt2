(set-logic QF_BV)
(declare-const x (_ BitVec 16))
(define-fun low () (_ BitVec 8) ((_ extract 7 0) x))
(define-fun high () (_ BitVec 8) ((_ extract 15 8) x))
; Decode the low/high LE pair back to the original word.
(assert (not (= (concat high low) x)))
(check-sat)
