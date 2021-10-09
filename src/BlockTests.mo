import Array "mo:base/Array";
import Blob  "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat8  "mo:base/Nat8";

import B    "./Block";
import Enc  "./Encoding";
import Hex  "./Hex";

func checkVarint(n : Nat64, repr : [Nat8]) : Bool {
  let enc = Enc.varint(n);
  if (Array.equal(enc, repr, Nat8.equal)) {
    true
  } else {
    Debug.print("Bad varint encoding for " # debug_show n # "\nExpected: " # debug_show repr # "\nActual:   " # debug_show enc);
    false
  }
};

func checkEncoding(b : B.Block, encHex : Text) : Bool {
  let expectedEnc = Hex.decode(encHex);
  let actualEnc = Enc.flatten(B.encode(b));
  if (Blob.equal(expectedEnc, actualEnc)) {
    true
  } else {
    Debug.print("Block:\n" # debug_show b # "\nencoding:\n" # debug_show (B.encode(b)) # "\nexpected enc: " # debug_show expectedEnc # "\nactual enc:   " # debug_show actualEnc);
    false
  }
};

func checkHash(b : B.Block, hashHex : Text) : Bool {
  let expectedHash = Hex.decode(hashHex);
  let actualHash = B.hash(b);
  if (Blob.equal(expectedHash, actualHash)) {
    true
  } else {
    Debug.print("Block:\n" # debug_show b # "\nexpected hash: " # debug_show expectedHash # "\nactual hash:   " # debug_show actualHash);
    false
  }
};

// Examples come from https://developers.google.com/protocol-buffers/docs/encoding
assert checkVarint(1, [0x01]);
assert checkVarint(150, [0x96, 0x01]);
assert checkVarint(300, [0xac, 0x02]);
assert checkVarint(270, [0x8e, 0x02]);
assert checkVarint(86942, [0x9e, 0xa7, 0x05]);

let b1 : B.Block = {
  parent_hash = null;
  transaction = {
    operation = #Mint {
      to = Hex.decode("424f9bb98fea906d31d17a702951a6b8f6ab109de112fd1d1553f66af9c2f93a");
      amount = { e8s = 10000000000 };
    };
    memo = 9991999599;
    created_at_time = { timestamp_nanos = 1234512345 };
  };
  timestamp = { timestamp_nanos = 1234567890 };
};

assert checkEncoding(b1, "120608d285d8cc041a3e122c12220a20424f9bb98fea906d31d17a702951a6b8f6ab109de112fd1d1553f66af9c2f93a1a060880c8afa025220608efa0c79c25320608d9d3d4cc04");
assert checkHash(b1, "714a76ddcaf861b74a73637816e78dc9b775306f62dc79ef33531ff102e0fd9f");
