; No finite binary32 input has a nonzero x - x, under RNE.
(set-logic QF_FP)
(declare-const x (_ FloatingPoint 8 24))
(assert (not (fp.isNaN x)))
(assert (not (fp.isInfinite x)))
(assert (not (fp.isZero (fp.sub RNE x x))))
(check-sat)
