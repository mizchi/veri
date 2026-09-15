; Base case of induction: Init => Safe.
(set-logic QF_UF)
(declare-const pending Bool)
(declare-const done Bool)
(assert (and (not pending) (not done)))
(assert (not (not (and pending done))))
(check-sat)
