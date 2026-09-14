; A concrete witness that a store can change the value at its key.
(set-logic QF_AUFLIA)
(define-fun a () (Array Int Int) ((as const (Array Int Int)) 0))
(define-fun updated () (Array Int Int) (store a 0 1))
(assert (distinct (select a 0) (select updated 0)))
(check-sat)
(get-value ((select a 0) (select updated 0)))
