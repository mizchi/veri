; Unsigned wrapping arithmetic: (x + y) - y always equals x.
(set-logic QF_BV)
(declare-const x (_ BitVec 32))
(declare-const y (_ BitVec 32))
(assert (distinct (bvsub (bvadd x y) y) x))
(check-sat)
