; A concrete witness, also used by the MoonBit negative proof control.
(set-logic QF_SLIA)
(define-fun left () String (str.++ "1" "2"))
(define-fun right () String (str.++ "2" "1"))
(assert (distinct left right))
(check-sat)
(get-value (left right))
