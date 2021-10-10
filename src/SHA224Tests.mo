import Array   "mo:base/Array";
import Blob    "mo:base/Blob";
import Debug   "mo:base/Debug";
import Text    "mo:base/Text";

import Hex     "./Hex";
import SHA224  "./SHA224";

func sha224(t : Text) : Blob {
  Blob.fromArray(SHA224.sha224(Blob.toArray(Text.encodeUtf8(t))))
};

func check(input : Text, hex : Text) : Bool {
  let left = sha224(input);
  let right = Hex.decode(hex);
  if (Blob.equal(left, right)) {
    true
  } else {
    Debug.print(debug_show left # " != " # debug_show right);
    false
  }
};

assert check("", "d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f");
assert check("The quick brown fox jumps over the lazy dog", "730e109bd7a8a32b1cb9d9a09aa2325d2430587ddbc0c38bad911525");
assert check("The quick brown fox jumps over the lazy dog.", "619cba8e8e05826e9b8c519c0a5c68f4fb653e8a3d8aa04bb2c8cd4c");
