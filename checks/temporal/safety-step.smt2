; Induction step: Safe /\ Next => Safe'. No reachability assumption.
; Together with safety-initial.smt2, this proves safety at every finite step.
(set-logic QF_UF)
(declare-const pending Bool)
(declare-const done Bool)
(declare-const pending_next Bool)
(declare-const done_next Bool)
(define-fun Request () Bool
  (and (not pending) (not done) pending_next (not done_next)))
(define-fun Complete () Bool
  (and pending (not done) (not pending_next) done_next))
(define-fun Stutter () Bool
  (and (= pending pending_next) (= done done_next)))
(assert (not (and pending done)))
(assert (or Request Complete Stutter))
(assert (and pending_next done_next))
(check-sat)
