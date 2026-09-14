; Concrete witness: all-ones is negative signed and largest unsigned.
(set-logic QF_BV)
(define-fun x () (_ BitVec 64) #xffffffffffffffff)
(assert (bvslt x #x0000000000000000))
(assert (bvugt x #x0000000000000000))
(assert (= (bvadd x #x0000000000000001) #x0000000000000000))
(check-sat)
(get-value (x))
