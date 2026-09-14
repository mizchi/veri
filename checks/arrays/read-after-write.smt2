; SMT arrays are total maps. There is no length or bounds precondition.
(set-logic QF_AUFLIA)
(declare-const a (Array Int Int))
(declare-const i Int)
(declare-const v Int)
(assert (distinct (select (store a i v) i) v))
(check-sat)
