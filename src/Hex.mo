import Array   "mo:base/Array";
import Blob    "mo:base/Blob";
import Iter    "mo:base/Iter";
import Nat8    "mo:base/Nat8";
import Prelude "mo:base/Prelude";
import Text    "mo:base/Text";

module {
  func hexDigit(b : Nat8) : Nat8 {
    switch (b) {
      case (48 or 49 or 50 or 51 or 52 or 53 or 54 or 55 or 56 or 57) { b - 48 };
      case (65 or 66 or 67 or 68 or 69 or 70) { 10 + (b - 65) };
      case (97 or 98 or 99 or 100 or 101 or 102) { 10 + (b - 97) };
      case _ { Prelude.nyi() };
    }
  };

  public func decode(t : Text) : Blob {
    assert (t.size() % 2 == 0);
    let n = t.size() / 2;
    let h = Blob.toArray(Text.encodeUtf8(t));
    var b : [var Nat8] = Array.init(n, Nat8.fromNat(0));
    for (i in Iter.range(0, n - 1)) {
      b[i] := hexDigit(h[2 * i]) << 4 | hexDigit(h[2 * i + 1]);
    };
    Blob.fromArrayMut(b)
  };
}
