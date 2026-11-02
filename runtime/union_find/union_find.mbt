///|
pub(all) suberror UnionFindError {
  NegativeSize(Int32)
  InvalidElement(Int32)
} derive(Debug, Eq)

///|
pub extend UnionFindError with @debug.Debug::{to_repr}

///|
pub extend UnionFindError with Eq::{not_equal, equal}

///|
/// Mutable disjoint sets on 0..<length. Union by size with path compression.
/// The runtime representation is differential-tested against flat partitions;
/// union_find contains the separate logical partition laws.
pub struct UnionFind {
  priv parents : Array[Int32]
  priv sizes : Array[Int32]
  priv mut components : Int32
}

///|
pub fn UnionFind::new(length : Int32) -> UnionFind raise UnionFindError {
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
pub fn UnionFind::length(self : UnionFind) -> Int32 {
  self.parents.length()
}

///|
pub fn UnionFind::component_count(self : UnionFind) -> Int32 {
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
  element : Int32,
) -> Unit raise UnionFindError {
  if element < 0 || element >= self.length() {
    raise InvalidElement(element)
  }
}

///|
fn UnionFind::root(self : UnionFind, element : Int32) -> Int32 {
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
  element : Int32,
) -> Int32 raise UnionFindError {
  self.validate(element)
  self.root(element)
}

///|
pub fn UnionFind::same(
  self : UnionFind,
  left : Int32,
  right : Int32,
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
  left : Int32,
  right : Int32,
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
  element : Int32,
) -> Int32 raise UnionFindError {
  self.validate(element)
  self.sizes[self.root(element)]
}

///|
/// A fresh array of representatives; this also compresses all paths.
pub fn UnionFind::to_array(self : UnionFind) -> Array[Int32] {
  Array::makei(self.length(), i => self.root(i))
}
