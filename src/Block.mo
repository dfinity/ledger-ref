import Array     "mo:base/Array";
import Blob      "mo:base/Blob";

import Account   "./Account";
import Encoding  "./Encoding";
import SHA256    "./SHA256";

module {
  public type ICP = { e8s : Nat64 };
  public type Timestamp = { timestamp_nanos : Nat64; };
  public type Memo = Nat64;
  public type Index = Nat64;
  public type BlockHash = Blob.Blob;
  public type Hash = Blob;
  
  public type Operation = {
    #Burn : { from : Account.Address; amount : ICP; };
    #Mint : { to : Account.Address; amount : ICP; };
    #Transfer : { from : Account.Address; to : Account.Address; amount : ICP; fee : ICP; };
  };
  
  public type Transaction = {
    operation : Operation;
    memo : Memo;
    created_at_time : Timestamp;
  };
  
  public type Block = {
    parent_hash : ?BlockHash;
    transaction : Transaction;
    timestamp : Timestamp;
  };

  func encodeAcc(field : Nat64, bytes : Blob.Blob) : Encoding.Encoding {
    Encoding.nested(field, Encoding.blob(1, bytes))
  };

  func encodeICP(field : Nat64, amount : ICP) : Encoding.Encoding {
    Encoding.nested(field, Encoding.nat64(1, amount.e8s))
  };

  func encodeTs(field : Nat64, ts : Timestamp) : Encoding.Encoding {
    Encoding.nested(field, Encoding.nat64(1, ts.timestamp_nanos))
  };

  func encodeTx(tx : Transaction) : Encoding.Encoding {
    #Concat ([
      switch (tx.operation) {
        case (#Burn { from; amount }) {
          Encoding.nested(1, #Concat ([ encodeAcc(1, from), encodeICP(3, amount) ]))
        };
        case (#Mint { to; amount}) {
          Encoding.nested(2, #Concat ([ encodeAcc(2, to), encodeICP(3, amount) ]))
        };
        case (#Transfer { from; to; amount; fee; }) {
          Encoding.nested(3, #Concat ([ encodeAcc(1, from), encodeAcc(2, to), encodeICP(3, amount), encodeICP(4, fee) ]))
        };
      },
      Encoding.nested(4, Encoding.nat64(1, tx.memo)),
      encodeTs(6, tx.created_at_time),
    ])
  };

  public func encode(b : Block) : Encoding.Encoding {
    #Concat ([
      switch (b.parent_hash) {
        case null { #Empty };
        case (?h) { Encoding.nested(1, Encoding.blob(1, h)) };
      },
      encodeTs(2, b.timestamp),
      Encoding.nested(3, encodeTx(b.transaction)),
    ])
  };

  public func hash(b : Block) : Hash {
    let digest = Encoding.fold(encode(b), SHA256.Digest(), func(d : SHA256.Digest, chunk : [Nat8]) : SHA256.Digest {
      d.write(chunk);
      d
    });

    Blob.fromArray(digest.sum())
  };
}
