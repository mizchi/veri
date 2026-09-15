///|
pub(all) suberror UnionFindError {
  NegativeSize(Int)
  InvalidElement(Int)
} derive(Debug, Eq)

///|
/// Mutable disjoint sets on 0..<length. Union by size with path compression.
/// The runtime representation is differential-tested against flat partitions;
/// union_find contains the separate logical partition laws.
pub struct UnionFind {
  priv parents : Array[Int]
  priv sizes : Array[Int]
  priv mut components : Int
}

///|
pub fn UnionFind::new(length : Int) -> UnionFind raise UnionFindError {
  if length < 0 {
    raise NegativeSize(length)
  }
  {
    parents: Array::makei(length, i => i),
    sizes: Array::make(length, 1),
    components: length,
  }
}

///|
pub fn UnionFind::length(self : UnionFind) -> Int {
  self.parents.length()
}

///|
pub fn UnionFind::component_count(self : UnionFind) -> Int {
  self.components
}

///|
pub fn UnionFind::copy(self : UnionFind) -> UnionFind {
  {
    parents: self.parents.copy(),
    sizes: self.sizes.copy(),
    components: self.components,
  }
}

///|
fn UnionFind::validate(
  self : UnionFind,
  element : Int,
) -> Unit raise UnionFindError {
  if element < 0 || element >= self.length() {
    raise InvalidElement(element)
  }
}

///|
fn UnionFind::root(self : UnionFind, element : Int) -> Int {
  let mut root = element
  while self.parents[root] != root {
    root = self.parents[root]
  }
  let mut vertex = element
  while self.parents[vertex] != vertex {
    let next = self.parents[vertex]
    self.parents[vertex] = root
    vertex = next
  }
  root
}

///|
/// Representative identity is unspecified; only equality between representatives
/// denotes connectivity. Finding compresses paths without changing components.
pub fn UnionFind::find(
  self : UnionFind,
  element : Int,
) -> Int raise UnionFindError {
  self.validate(element)
  self.root(element)
}

///|
pub fn UnionFind::same(
  self : UnionFind,
  left : Int,
  right : Int,
) -> Bool raise UnionFindError {
  self.validate(left)
  self.validate(right)
  self.root(left) == self.root(right)
}

///|
/// Return true exactly when two different components were joined. Validate both
/// inputs before any mutation. Repeated unions leave the partition unchanged.
pub fn UnionFind::union(
  self : UnionFind,
  left : Int,
  right : Int,
) -> Bool raise UnionFindError {
  self.validate(left)
  self.validate(right)
  let a = self.root(left)
  let b = self.root(right)
  if a == b {
    return false
  }
  let (large, small) = if self.sizes[a] < self.sizes[b] {
    (b, a)
  } else {
    (a, b)
  }
  self.parents[small] = large
  self.sizes[large] += self.sizes[small]
  self.components -= 1
  true
}

///|
pub fn UnionFind::component_size(
  self : UnionFind,
  element : Int,
) -> Int raise UnionFindError {
  self.validate(element)
  self.sizes[self.root(element)]
}

///|
/// A fresh array of representatives; this also compresses all paths.
pub fn UnionFind::to_array(self : UnionFind) -> Array[Int] {
  Array::makei(self.length(), i => self.root(i))
}
