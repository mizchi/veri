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
test "quickcheck: map traces match an association list even with constant hashes" {
  @quickcheck.check(
    (commands : Array[(Int, Int, Int)]) => {
      let actual : @map.Map[Key, Int] = Map([])
      let mut expected : Array[(Key, Int)] = []
      for (tag, raw_key, value) in commands {
        let key = Key::{ value: raw_key % 8, }
        match (tag % 4).abs() {
          0 => {
            actual.set(key, value)
            expected = expected.filter(pair => pair.0 != key)
            expected.push((key, value))
          }
          1 => {
            actual.remove(key)
            expected = expected.filter(pair => pair.0 != key)
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
        if !@map.matches_entries(actual, expected[:]) ||
          actual.length() != expected.length() {
          return false
        }
        for k = -7; k <= 7; k = k + 1 {
          let key = Key::{ value: k, }
          let mut found : Int? = None
          for (candidate, value) in expected {
            if candidate == key {
              found = Some(value)
            }
          }
          if actual.get(key) != found ||
            actual.contains(key) != (found is Some(_)) {
            return false
          }
        }
      }
      true
    },
    count=500,
    max_size=64,
    max_shrinks=1000,
    seed=20260919,
  )
}
