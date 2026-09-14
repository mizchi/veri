; Look for any violation of negation preserving NaN classification.
(set-logic QF_FP)
(declare-const x (_ FloatingPoint 11 53))
(assert (distinct (fp.isNaN x) (fp.isNaN (fp.neg x))))
(check-sat)
