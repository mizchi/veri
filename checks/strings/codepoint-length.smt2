; An astral character has length 1 in SMT Unicode strings (not UTF-16 units).
(set-logic QF_SLIA)
(assert (distinct (str.len "\u{1f600}") 1))
(check-sat)
