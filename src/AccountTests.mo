import Blob      "mo:base/Blob";
import Debug     "mo:base/Debug";
import Option    "mo:base/Option";
import Principal "mo:base/Principal";

import Account   "./Account";
import Hex       "./Hex";

func check(principalText : Text, subaccountHex : ?Text, accIdHex : Text) : Bool {
  let principal = Principal.fromText(principalText);
  let subaccount = Option.getMapped(subaccountHex, Hex.decode, Account.defaultSubaccount());
  let actualAccId = Account.accountIdentifier(principal, subaccount);
  let expectedAccId = Hex.decode(accIdHex);
  if (Blob.equal(expectedAccId, actualAccId)) {
    true
  } else {
    Debug.print("Expected: " # debug_show expectedAccId # "\nActual:   " # debug_show actualAccId);
    false
  }
};

assert Account.validAccountIdentifier(Hex.decode("bdc4ee05d42cd0669786899f256c8fd7217fa71177bd1fa7b9534f568680a938"));
assert check("iooej-vlrze-c5tme-tn7qt-vqe7z-7bsj5-ebxlc-hlzgs-lueo3-3yast-pae", null, "bdc4ee05d42cd0669786899f256c8fd7217fa71177bd1fa7b9534f568680a938");
