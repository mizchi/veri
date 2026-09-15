(set-logic QF_BV)
(declare-const x (_ BitVec 8))
; Widening then narrowing preserves every byte.
(assert (not (= ((_ extract 7 0) ((_ zero_extend 8) x)) x)))
(check-sat)
