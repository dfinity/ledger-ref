# ICP Ledger Reference Implementation

This repository contains the reference implementation of ICP ledger in Motoko.

## Building

You'll need to have [docker](https://www.docker.com/) installed in order to build the canister.

Execute the following commands in your checkout of this repository

```
docker build -t ledger-ref .
docker run --rm ledger-ref cat ledger.wasm > ledger.wasm
```

Those commands will create a `ledger.wasm` canister module that you can install and play with.
