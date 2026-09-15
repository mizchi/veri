; Fixed single-job model: Init = idle; Next = request, complete, or stutter.
; p = pending; d = done. Request: idle -> pending; Complete: pending -> done.
; Counterexample to G(pending => F done): states 0..4, state 4 = state loop.
; A pending state has no done state in its future suffix OR any loop state.
; Weak fairness, when enabled: some loop state disables Complete, or a loop edge completes.
; This query checks exactly four transitions. UNSAT is not an unbounded liveness proof.
(set-logic QF_LIA)
(declare-const p0 Bool)
(declare-const d0 Bool)
(declare-const p1 Bool)
(declare-const d1 Bool)
(declare-const p2 Bool)
(declare-const d2 Bool)
(declare-const p3 Bool)
(declare-const d3 Bool)
(declare-const p4 Bool)
(declare-const d4 Bool)
(declare-const loop Int)
(assert (and (not p0) (not d0)))
(assert
  (or
    (and (not p0) (not d0) p1 (not d1))
    (and (and p0 (not d0)) (not p1) d1)
    (and (= p0 p1) (= d0 d1))))
(assert
  (or
    (and (not p1) (not d1) p2 (not d2))
    (and (and p1 (not d1)) (not p2) d2)
    (and (= p1 p2) (= d1 d2))))
(assert
  (or
    (and (not p2) (not d2) p3 (not d3))
    (and (and p2 (not d2)) (not p3) d3)
    (and (= p2 p3) (= d2 d3))))
(assert
  (or
    (and (not p3) (not d3) p4 (not d4))
    (and (and p3 (not d3)) (not p4) d4)
    (and (= p3 p4) (= d3 d4))))
(assert
  (or
    (and
      (= loop 0)
      (and (= p4 p0) (= d4 d0))
      (or
        (and p0 (not d0) (not d1) (not d2) (not d3) (not d0) (not d1) (not d2) (not d3))
        (and p1 (not d1) (not d2) (not d3) (not d0) (not d1) (not d2) (not d3))
        (and p2 (not d2) (not d3) (not d0) (not d1) (not d2) (not d3))
        (and p3 (not d3) (not d0) (not d1) (not d2) (not d3)))
      (or
        (not (and p0 (not d0)))
        (not (and p1 (not d1)))
        (not (and p2 (not d2)))
        (not (and p3 (not d3)))
        (and (and p0 (not d0)) (not p1) d1)
        (and (and p1 (not d1)) (not p2) d2)
        (and (and p2 (not d2)) (not p3) d3)
        (and (and p3 (not d3)) (not p4) d4)))
    (and
      (= loop 1)
      (and (= p4 p1) (= d4 d1))
      (or
        (and p0 (not d0) (not d1) (not d2) (not d3) (not d1) (not d2) (not d3))
        (and p1 (not d1) (not d2) (not d3) (not d1) (not d2) (not d3))
        (and p2 (not d2) (not d3) (not d1) (not d2) (not d3))
        (and p3 (not d3) (not d1) (not d2) (not d3)))
      (or
        (not (and p1 (not d1)))
        (not (and p2 (not d2)))
        (not (and p3 (not d3)))
        (and (and p1 (not d1)) (not p2) d2)
        (and (and p2 (not d2)) (not p3) d3)
        (and (and p3 (not d3)) (not p4) d4)))
    (and
      (= loop 2)
      (and (= p4 p2) (= d4 d2))
      (or
        (and p0 (not d0) (not d1) (not d2) (not d3) (not d2) (not d3))
        (and p1 (not d1) (not d2) (not d3) (not d2) (not d3))
        (and p2 (not d2) (not d3) (not d2) (not d3))
        (and p3 (not d3) (not d2) (not d3)))
      (or
        (not (and p2 (not d2)))
        (not (and p3 (not d3)))
        (and (and p2 (not d2)) (not p3) d3)
        (and (and p3 (not d3)) (not p4) d4)))
    (and
      (= loop 3)
      (and (= p4 p3) (= d4 d3))
      (or
        (and p0 (not d0) (not d1) (not d2) (not d3) (not d3))
        (and p1 (not d1) (not d2) (not d3) (not d3))
        (and p2 (not d2) (not d3) (not d3))
        (and p3 (not d3) (not d3)))
      (or (not (and p3 (not d3))) (and (and p3 (not d3)) (not p4) d4)))))
(check-sat)
