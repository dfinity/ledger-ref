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


actor class Ledger(init : {
                     initial_mints : [ { account : Account.AccountIdentifier; amount : { e8s : Nat64 } } ];
                     minting_account : ?Account.AccountIdentifier;
                  }) = this {

  public type Subaccount = Account.Subaccount;
  public type AccountIdentifier = Account.AccountIdentifier;
  public type ICP = Block.ICP;
  public type Memo = Block.Memo;
  public type Timestamp = Block.Timestamp;
  public type BlockIndex = Block.Index;
  public type BlockChain = List.List<Block.Block>;

  let permittedDriftNanos : Nat64 = 60_000_000_000;
  let expectedFee : Nat64 = 10_000;
  let transactionWindowNanos : Nat64 = 24 * 60 * 60 * 1_000_000_000;
  let defaultSubaccount : Subaccount = Account.defaultSubaccount(); 


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

  func mintingAccountId() : AccountIdentifier {
    switch (init.minting_account) {
      case (?acc) { acc };
      case null { Account.accountIdentifier(Principal.fromActor(this), defaultSubaccount) };
    }
  };

  func transactionsEqual(l : Block.Transaction, r : Block.Transaction) : Bool {
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

  func balance(address : AccountIdentifier, blocks : BlockChain) : Nat64 {
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

  func findTransaction(t : Block.Transaction, blocks : BlockChain) : ?BlockIndex {
    func go(h : BlockIndex, rest : BlockChain) : ?BlockIndex {
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

  func isAnonymous(p : Principal) : Bool {
    Blob.equal(Principal.toBlob(p), Blob.fromArray([0x04]))
  };

  func makeGenesisChain() : BlockChain {
    let now = Nat64.fromNat(Int.abs(Time.now()));

    let (hash, blocks) = Array.foldLeft<{ account : AccountIdentifier; amount : ICP }, (?Block.Hash, BlockChain)>(
        init.initial_mints,
        (null : ?Block.Hash, null : BlockChain),
        func((parent_hash : ?Block.Hash, chain : BlockChain), { account: AccountIdentifier; amount : ICP }) : (?Block.Hash, BlockChain) {

      let block : Block.Block = {
        parent_hash = parent_hash;
        transaction = {
          operation = #Mint({ to = account; amount = amount; });
          memo = 0;
          created_at_time = { timestamp_nanos = now };
        };
        timestamp = { timestamp_nanos = now };
      };
      let hash = Block.hash(block);
      (?hash, List.push(block, chain))
    });

    switch (hash) {
      case (?hash) { CertifiedData.set(hash); };
      case null { CertifiedData.set(Blob.fromArray(Array.freeze(Array.init<Nat8>(32, 0)))); };
    };

    blocks
  };

  stable var blocks : BlockChain = makeGenesisChain();

  public shared({ caller }) func transfer({
      memo : Memo;
      amount : ICP;
      fee : ICP;
      subaccount : ?Subaccount;
      to : AccountIdentifier;
      created_at_time : ?Timestamp;
  }) : async TransferResult {
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

    if (not Account.validAccountIdentifier(to)) {
      throw Error.reject(debug_show(to) # " is not a valid address");
    };

    let debitAccId = Account.accountIdentifier(caller, Option.get(subaccount, defaultSubaccount));

    let mintingAccId = mintingAccountId();

    let operation = if (Blob.equal(debitAccId, mintingAccId)) {
      #Mint {
        to = to;
        amount = amount;
      }
    } else if (Blob.equal(to, mintingAccId)) {
      if (fee.e8s != 0) {
        return #Err(#BadFee { expected_fee = { e8s = 0 } });
      };

      if (amount.e8s < expectedFee) {
        throw Error.reject("Cannot BURN less than " # debug_show(expectedFee));
      };

      let debitBalance = balance(debitAccId, blocks);
      if (debitBalance < amount.e8s) {
        return #Err(#InsufficientFunds { balance = { e8s = debitBalance } });
      };

      #Burn {
        from = debitAccId;
        amount = amount;
      }
    } else {
      if (fee.e8s != expectedFee) {
        return #Err(#BadFee { expected_fee = { e8s = expectedFee } });
      };

      let debitBalance = balance(debitAccId, blocks);
      if (debitBalance < amount.e8s + fee.e8s) {
        return #Err(#InsufficientFunds { balance = { e8s = debitBalance } });
      };

      #Transfer {
        from = debitAccId;
        to = to;
        amount = amount;
        fee = fee;
      }
    };

    let transaction = {
      operation = operation;
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

  public query func account_balance({ account : AccountIdentifier }) : async ICP {
    { e8s = balance(account, blocks); }
  }
}
