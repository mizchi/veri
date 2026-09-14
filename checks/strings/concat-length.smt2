; Look for a violation of additive string length.
(set-logic QF_SLIA)
(declare-const a String)
(declare-const b String)
(assert (distinct (str.len (str.++ a b)) (+ (str.len a) (str.len b))))
(check-sat)
