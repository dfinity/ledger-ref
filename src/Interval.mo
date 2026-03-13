import Nat64 "mo:base/Nat64";

module {
  // A half-open interval of integers ranging from [from] (inclusively) to [to] (exclusively).
  // INVARIANT: from <= to
  public type Interval = { from : Nat64; to : Nat64 };

  // Constructs a new interval from the starting point and the length.
  //
  // POST-CONDITION: length(fromLength(start, length)) == length
  public func fromLength(start : Nat64, length : Nat64) : Interval {
    { from = start; to = start + length; }
  };

  // Returns an intersection of input intervals.
  public func intersect(x : Interval, y : Interval) : Interval {
    assert x.from <= x.to;
    assert y.from <= y.to;

    let b = Nat64.max(x.from, y.from);
    let e = Nat64.min(x.to, y.to);
    { from = b; to = Nat64.max(b, e); }
  };

  // Returns true iff interval [x] doesn't contain any points.
  public func isEmpty(x : Interval) : Bool {
    x.from >= x.to
  };

  // Returns the number of integers in interval [x].
  public func length(x : Interval) : Nat64 {
    assert x.from <= x.to;
    x.to - x.from
  };

  // Returns true iff interval [x] contains integer [n].
  public func contains(x : Interval, n : Nat64) : Bool {
    x.from <= n and n < x.to
  };

  // Returns true iff [x] is a sub-interval of [y] (all elements of [x] also belong to [y]).
  public func isSubIntervalOf(x : Interval, y : Interval) : Bool {
    assert x.from <= x.to;
    assert y.from <= y.to;

    y.from <= x.from and x.to <= y.to
  };

  // Returns a prefix of interval [x] that contains at most [n] elements.
  //
  // head(x, n) == intersect(x, fromLength(x.from, n))
  public func head(x : Interval, n : Nat64) : Interval {
    assert x.from <= x.to;

    { from = x.from; to = Nat64.min(x.to, x.to + n); }
  };

  // Returns the suffix of interval [x] that contains at most [n] elements.
  public func tail(x : Interval, n : Nat64) : Interval {
    assert x.from <= x.to;

    let len = length(x);
    if (len < n) { x } else { { from = x.to - n; to = x.to } };
  };

  // Returns the interval constructed by removing [n] last elements from interval [x].
  public func betail(x : Interval, n : Nat64) : Interval {
    assert x.from <= x.to;

    let t = tail(x, n);
    { from = x.from; to = t.from }
  };
}
