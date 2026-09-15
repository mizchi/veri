///|
priv struct Key {
  value : Int
} derive(Eq)

///|
impl Hash for Key with fn hash_combine(self, hasher) {
  ignore(self)
  hasher.combine_int(0)
}

///|
test "quickcheck: set traces and algebra match distinct arrays with constant hashes" {
  @quickcheck.check(
    (commands : Array[(Int, Int)]) => {
      let actual : @set.Set[Key] = Set([])
      let mut expected : Array[Key] = []
      for (tag, raw_key) in commands {
        let key = Key::{ value: raw_key % 8, }
        match (tag % 4).abs() {
          0 => {
            let fresh = !expected.contains(key)
            if actual.add_and_check(key) != fresh {
              return false
            }
            if fresh {
              expected.push(key)
            }
          }
          1 => {
            if actual.remove_and_check(key) != expected.contains(key) {
              return false
            }
            expected = expected.filter(k => k != key)
          }
          2 => {
            let copy = actual.copy()
            copy.clear()
            if !copy.is_empty() {
              return false
            }
          }
          _ => {
            actual.clear()
            expected.clear()
          }
        }
        if actual.length() != expected.length() ||
          !@set.matches_elements(actual, expected[:]) {
          return false
        }
        let other = Set([Key::{ value: 0, }, Key::{ value: 1, }])
        let union = actual.union(other)
        let intersection = actual.intersection(other)
        let difference = actual.difference(other)
        for k = -7; k <= 7; k = k + 1 {
          let key = Key::{ value: k, }
          let a = expected.contains(key)
          let b = k == 0 || k == 1
          if actual.contains(key) != a ||
            union.contains(key) != (a || b) ||
            intersection.contains(key) != (a && b) ||
            difference.contains(key) != (a && !b) {
            return false
          }
        }
      }
      true
    },
    count=500,
    max_size=64,
    max_shrinks=1000,
    seed=20260920,
  )
}
