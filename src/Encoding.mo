// Encode data as protocol buffers.
//
// For the cases we care about, protocol buffers represent messages as a
// sequence of key-value pairs, where key is an integer indicating message
// field number (assigned manually by a programmer) and the value is either
// an integer or a byte sequence.
//
// Fields containing nested messages are encoded recursively and then treated
// as bytes, which makes it impossible to distinguish them on the wire without
// a schema.
//
// See https://developers.google.com/protocol-buffers/docs/encoding for more details
// on the protobuf encoding.
//
// Note [default values]
// =====================
// Protobuf encoding optimizes away default values of primitive fields.
// If the field value is equal to default value of the corresponding type
// (zero integers, empty blobs and strings), the field is not included into
// the output.

import Array     "mo:base/Array";
import Blob      "mo:base/Blob";
import Prelude   "mo:base/Prelude";
import Nat8      "mo:base/Nat8";
import Nat64     "mo:base/Nat64";

module {
  // This representation of encoding allows us to build larger message from little
  // pieces without unnecessary copying byte arrays.
  public type Encoding = {
    // Empty sequence of bytes.
    #Empty;
    // A single chunk of bytes.
    #Flat   : [Nat8];
    // A concatenation of zero or more encodings.
    #Concat : [Encoding];
  };

  // Folds chunks of the encoding.
  public func fold<A>(enc : Encoding, acc : A, step : (A, [Nat8]) -> A) : A {
    switch (enc) {
      case (#Empty) { acc };
      case (#Flat chunk) { step(acc, chunk) };
      case (#Concat parts) {
        Array.foldLeft(parts, acc, func (x: A, e: Encoding) : A { fold(e, x, step) })
      };
    }
  };

  // Encodes an integer into Base 128 varint encoding.
  public func varint(n : Nat64) : [Nat8] {
    func byte(n : Nat64) : Nat8 { Nat8.fromNat(Nat64.toNat(n & 0xff)) };

    if (n < 128) { [byte(n)] }
    else { Array.append([byte(n & 0x7f) | 0x80], varint(n >> 7)) }
  };

  // Returns the total length of the encoding in bytes.
  public func size(enc : Encoding) : Nat64 {
    fold(enc, 0 : Nat64, func(sum: Nat64, chunk: [Nat8]) : Nat64 { sum + Nat64.fromNat(chunk.size()) })
  };

  // Encode a numeric field as part of a protobuf message.
  public func nat64(field : Nat64, n : Nat64) : Encoding {
    assert (field < (1 << 61));
    if (n == 0) {
      // Note [default values]
      #Empty
    } else {
      #Concat ([#Flat (varint(field << 3)), #Flat (varint(n))])
    }
  };

  // Encodes a "length-delimited" field of a protobuf message.
  // Protocol buffers use this encoding for strings, blobs, and nested messages.
  public func nested(fieldNumber : Nat64, enc : Encoding) : Encoding {
    // Note: nested messages are encoded just as primitive bytes field, 
    // but for some reason empty value optimization does apply.
    #Concat ([#Flat (varint((fieldNumber << 3) | 2)), #Flat (varint(size(enc))), enc]) 
  };

  // Encodes a field of type "bytes".
  public func blob(fieldNumber : Nat64, b : Blob) : Encoding {
    if (b.size() == 0) {
      // Note [default values]
      #Empty
    } else {
      nested(fieldNumber, #Flat (Blob.toArray(b)))
    }
  };

  // Materializes the encoding as a contiguous byte array.
  public func flatten(enc : Encoding) : Blob {
    Blob.fromArray(fold<[Nat8]>(enc, [], func(buf : [Nat8], chunk : [Nat8]) { Array.append(buf, chunk) }))
  };
}
