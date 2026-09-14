; SMT value identity includes zero's sign. The model has one abstract NaN;
; this property makes no claim about preserving a runtime NaN payload.
(set-logic QF_FP)
(declare-const x (_ FloatingPoint 8 24))
(assert (not (= x ((_ to_fp 8 24) RNE ((_ to_fp 11 53) RNE x)))))
(check-sat)
