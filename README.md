<h1 align="center">
  <br>
  <img width="320" src="nix-bitcoin-core-archive.png" alt="nix-polkadot logo">
  <br>
Nix Bitcoin Core Archive
<br>
</h1>

[nix-bitcoin](https://github.com/fort-nix/nix-bitcoin) is useful for running up-to-date `bitcoin-core`.

But sometimes, we need to run old or patched releases in a nix environment.

`nix-bitcoin-core-archive` provides Nix derivations for:
- old and outdated `bitcoin-core` releases
- custom forks

## instructions

Just `cd` into the directory of the chosen version, and then do a `nix-build`. The build artifacts will be placed at `result`. For example, if you want to run `0.21.0`:
```
$ cd core/0.21.0
$ nix-build
$ ls result/bin
bitcoin-cli  bitcoind  bitcoin-tx  bitcoin-util
```

---

# Bitcoin Core

 - [ ] Bitcoin Core v25.1
 - [ ] Bitcoin Core v25.0
 - [ ] Bitcoin Core v24.2
 - [ ] Bitcoin Core v24.1
 - [ ] Bitcoin Core v24.0.1
 - [ ] Bitcoin Core v23.2
 - [ ] Bitcoin Core v23.1
 - [ ] Bitcoin Core v23.0
 - [ ] Bitcoin Core v22.1
 - [x] Bitcoin Core v22.0
 - [ ] Bitcoin Core v0.21.2
 - [ ] Bitcoin Core v0.21.1
 - [x] Bitcoin Core v0.21.0
 - [ ] Bitcoin Core v0.20.2
 - [ ] Bitcoin Core v0.20.1
 - [ ] Bitcoin Core v0.20.0
 - [ ] Bitcoin Core v0.19.1
 - [ ] Bitcoin Core v0.19.0.1
 - [ ] Bitcoin Core v0.18.1
 - [ ] Bitcoin Core v0.18.0
 - [ ] Bitcoin Core v0.17.1
 - [ ] Bitcoin Core v0.17.0.1
 - [ ] Bitcoin Core v0.17.0
 - [ ] Bitcoin Core v0.16.3
 - [ ] Bitcoin Core v0.16.2
 - [ ] Bitcoin Core v0.16.1
 - [ ] Bitcoin Core v0.16.0
 - [ ] Bitcoin Core v0.15.2
 - [ ] Bitcoin Core v0.15.1
 - [ ] Bitcoin Core v0.15.0.1
 - [ ] Bitcoin Core v0.15.0
 - [ ] Bitcoin Core v0.14.3
 - [ ] Bitcoin Core v0.14.2
 - [ ] Bitcoin Core v0.14.1
 - [ ] Bitcoin Core v0.14.0
 - [ ] Bitcoin Core v0.13.2
 - [ ] Bitcoin Core v0.13.1
 - [ ] Bitcoin Core v0.13.0
 - [ ] Bitcoin Core v0.12.1
 - [ ] Bitcoin Core v0.12.0
 - [ ] Bitcoin Core v0.11.2
 - [ ] Bitcoin Core v0.11.1
 - [ ] Bitcoin Core v0.11.0

---

# Custom Forks

- [x] [SV2 Patch by @Sjors](https://github.com/Sjors/bitcoin/tree/sv2m) - v25.99.0
- [x] [SV2 + testnet4 Patch by @Sjors + @fjahr + @stratospher](https://github.com/stratospher/bitcoin/tree/sv2-testnet4) - v25.99.0
- [x] [MutinyNet Patch by @benthecarman](https://github.com/benthecarman/bitcoin) - v24.99.0
