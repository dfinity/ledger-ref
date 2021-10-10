import Array         "mo:base/Array";
import CertifiedData "mo:base/CertifiedData";
import List          "mo:base/List";
import Blob          "mo:base/Blob";
import Principal     "mo:base/Principal";
import Option        "mo:base/Option";
import Error         "mo:base/Error";
import Text          "mo:base/Text";
import Time          "mo:base/Time";
import Int           "mo:base/Int";
import Nat8          "mo:base/Nat8";
import Nat32         "mo:base/Nat32";
import Nat64         "mo:base/Nat64";

import Account       "./Account";
import Block         "./Block";

actor Self {
  let permittedDriftNanos : Nat64 = 60_000_000_000;
  let expectedFee : Nat64 = 10_000;
  let transactionWindowNanos : Nat64 = 24 * 60 * 60 * 1_000_000_000;
  let defaultSubaccount : Subaccount = Account.defaultSubaccount(); 

  public type Subaccount = Account.Subaccount;
  public type Address = Account.Address;
  public type ICP = Block.ICP;
  public type Memo = Block.Memo;
  public type Timestamp = Block.Timestamp;
  public type BlockIndex = Block.Index;

  public type TransferError = {
    #BadFee : { expected_fee : ICP };
    #InsufficientFunds : { balance : ICP };
    #TxTooOld : { allowed_window_nanos : Nat64 };
    #TxCreatedInFuture;
    #TxDuplicate : { duplicate_of : BlockIndex };
  };
  
  public type TransferResult = {
    #Ok  : BlockIndex;
    #Err : TransferError;
  };

  func transactionsEqual(l: Block.Transaction, r: Block.Transaction) : Bool {
    if (l.memo != r.memo) return false;
    if (l.created_at_time.timestamp_nanos != r.created_at_time.timestamp_nanos) return false;
    switch ((l.operation, r.operation)) {
      case (#Burn { from = lfrom; amount = lamount; }, #Burn { from = rfrom; amount = ramount}) {
        Blob.equal(lfrom, rfrom) and lamount.e8s == ramount.e8s
      };
      case (#Mint { to = lto; amount = lamount; }, #Mint { to = rto; amount = ramount}) {
        Blob.equal(lto, rto) and lamount.e8s == ramount.e8s
      };
      case (#Transfer { from = lfrom; to = lto; amount = lamount; fee = lfee; }, #Transfer { from = rfrom; to = rto; amount = ramount; fee = rfee}) {
        Blob.equal(lfrom, lto) and Blob.equal(lto, rto) and lamount.e8s == ramount.e8s and lfee.e8s == rfee.e8s
      };
      case _ { false };
    }
  };

  func balance(address: Address, blocks: List.List<Block.Block>) : Nat64 {
    List.foldLeft(blocks, 0 : Nat64, func(sum : Nat64, block : Block.Block) : Nat64 {
      switch (block.transaction.operation) {
        case (#Burn { from; amount; }) {
          if (from == address) { sum - amount.e8s } else { sum }
        };
        case (#Mint { to; amount; }) {
          if (to == address) { sum + amount.e8s } else { sum }
        };
        case (#Transfer { from; to; amount; fee; }) {
          if (from == address) { sum - amount.e8s - fee.e8s }
          else if (to == address) { sum + amount.e8s }
          else { sum }
        }
      }
    })
  };

  func findTransaction(t: Block.Transaction, blocks: List.List<Block.Block>) : ?BlockIndex {
    func go(h: BlockIndex, rest: List.List<Block.Block>) : ?BlockIndex {
      switch rest {
        case null { null };
        case (?(block, tail)) { if (transactionsEqual(t, block.transaction)) { ?h } else { go(h + 1, tail) } };
      }
    };
    go(0, blocks)
  };

  func tipHash() : ?Block.Hash {
    switch blocks {
      case null { null };
      case (?(tip, _)) { ?Block.hash(tip) };
    }
  };

  func isAnonymous(p: Principal) : Bool {
    Blob.equal(Principal.toBlob(p), Blob.fromArray([0x04]))
  };

  stable var blocks : List.List<Block.Block> = null;

  public shared({ caller }) func transfer({
      memo: Memo;
      amount: ICP;
      fee: ICP;
      subaccount: ?Subaccount;
      to: Address;
      created_at_time: ?Timestamp;
  }): async TransferResult {
    if (isAnonymous(caller)) {
      throw Error.reject("anonymous user is not allowed to transfer funds");
    };

    let now = Nat64.fromNat(Int.abs(Time.now()));

    let txTime: Nat64 = switch (created_at_time) {
      case (null) { now };
      case (?ts) { ts.timestamp_nanos };
    };

    if ((txTime > now) and (txTime - now > permittedDriftNanos)) {
      return #Err(#TxCreatedInFuture);
    };

    if ((txTime < now) and (now - txTime > transactionWindowNanos)) {
      return #Err(#TxTooOld { allowed_window_nanos = transactionWindowNanos });
    };

    switch (Account.validateAddress(to)) {
      case (null) { throw Error.reject(debug_show(to) # " is not a valid address") };
      case (?_) { };
    };

    let debitAddress = Account.address(caller, Option.get(subaccount, defaultSubaccount));

    let debitBalance = balance(debitAddress, blocks);
    if (debitBalance < amount.e8s + fee.e8s) {
      return #Err(#InsufficientFunds { balance = { e8s = 0 } });
    };

    if (fee.e8s != expectedFee) {
      return #Err(#BadFee { expected_fee = { e8s = expectedFee } });
    };

    let transaction = {
      operation = #Transfer {
        from = debitAddress;
        to = to;
        amount = amount;
        fee = fee;
      };
      memo = memo;
      created_at_time = { timestamp_nanos = txTime };
    };

    switch (findTransaction(transaction, blocks)) {
      case (?height) { return #Err(#TxDuplicate { duplicate_of = height }) };
      case null { };
    };

    let newBlock : Block.Block = {
      parent_hash = tipHash();
      transaction = transaction;
      timestamp = { timestamp_nanos = now };
    };

    CertifiedData.set(Block.hash(newBlock));

    let blockHeight = List.size(blocks);
    blocks := List.push(newBlock, blocks);
    #Ok(Nat64.fromNat(blockHeight))
  };

  public func account_balance({ account: Address }): async ICP {
    { e8s = balance(account, blocks); }
  }
}
