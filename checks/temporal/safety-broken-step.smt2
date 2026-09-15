; Negative control: completing without clearing pending violates safety.
(set-logic QF_UF)
(declare-const pending Bool)
(declare-const done Bool)
(declare-const pending_next Bool)
(declare-const done_next Bool)
(define-fun Request () Bool
  (and (not pending) (not done) pending_next (not done_next)))
(define-fun BrokenComplete () Bool
  (and pending (not done) pending_next done_next))
(define-fun Stutter () Bool
  (and (= pending pending_next) (= done done_next)))
(assert (not (and pending done)))
(assert (or Request BrokenComplete Stutter))
(assert (and pending_next done_next))
(check-sat)
(get-value (pending done pending_next done_next))
