; The next binary64 value above 1 rounds to binary32 1 under RNE.
(set-logic QF_FP)
(define-fun value () (_ FloatingPoint 11 53) ((_ to_fp 11 53) #x3ff0000000000001))
(define-fun result () (_ FloatingPoint 11 53)
  ((_ to_fp 11 53) RNE ((_ to_fp 8 24) RNE value)))
(assert (not (fp.eq value result)))
(check-sat)
(get-value (value result))
