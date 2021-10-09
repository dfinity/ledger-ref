import Array     "mo:base/Array";
import Blob      "mo:base/Blob";
import Prelude   "mo:base/Prelude";
import Nat8      "mo:base/Nat8";
import Nat64     "mo:base/Nat64";

module {
  public type Encoding = {
    #Empty;
    #Flat   : [Nat8];
    #Concat : [Encoding];
  };

  public func fold<A>(enc: Encoding, acc: A, step: (A, [Nat8]) -> A) : A {
    switch (enc) {
      case (#Empty) { acc };
      case (#Flat chunk) { step(acc, chunk) };
      case (#Concat parts) {
        Array.foldLeft(parts, acc, func (x: A, e: Encoding) : A { fold(e, x, step) })
      };
    }
  };

  public func varint(n: Nat64) : [Nat8] {
    func byte(n: Nat64) : Nat8 { Nat8.fromNat(Nat64.toNat(n & 0xff)) };

    if (n < 128) { [byte(n)] }
    else { Array.append([byte(n & 0x7f) | 0x80], varint(n >> 7)) }
  };

  public func size(enc: Encoding) : Nat64 {
    fold(enc, 0 : Nat64, func(sum: Nat64, chunk: [Nat8]) : Nat64 { sum + Nat64.fromNat(chunk.size()) })
  };

  public func nat64(field: Nat64, n: Nat64) : Encoding {
    assert (field < (1 << 61));
    if (n == 0) { #Empty }
    else { #Concat ([#Flat (varint(field << 3)), #Flat (varint(n))]) }
  };

  public func nested(field: Nat64, enc: Encoding) : Encoding {
    let encSize = size(enc);
    //#Concat ([#Flat (varint((field << 3) | 2)), #Flat (varint(encSize)), enc]) 
    if (encSize == 0) { #Empty }
    else { #Concat ([#Flat (varint((field << 3) | 2)), #Flat (varint(encSize)), enc]) }
  };

  public func blob(field: Nat64, b: Blob) : Encoding {
    nested(field, #Flat (Blob.toArray(b)))
  };

  public func flatten(enc : Encoding) : Blob {
    Blob.fromArray(fold<[Nat8]>(enc, [], func(buf : [Nat8], chunk : [Nat8]) { Array.append(buf, chunk) }))
  };
}
