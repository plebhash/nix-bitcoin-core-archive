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

Note: `darwin` is not yet supported. Derivarions are only tested on Linux.

## instructions

Just `cd` into the directory of the chosen version, and then do a `nix-build`. The build artifacts will be placed at `result`. For example, if you want to run `0.21.0`:
```
$ cd core/0.21.0
$ nix-build
$ ls result/bin
bitcoin-cli  bitcoind  bitcoin-qt  bitcoin-tx  bitcoin-wallet
```

---

# Bitcoin Core

- [x] Bitcoin Core v31.1
- [x] Bitcoin Core v31.0
- [x] Bitcoin Core v30.3
- [x] Bitcoin Core v30.2
- [x] Bitcoin Core v30.1
- [x] Bitcoin Core v30.0
- [x] Bitcoin Core v29.4
- [x] Bitcoin Core v29.3
- [x] Bitcoin Core v29.2
- [x] Bitcoin Core v29.1
- [x] Bitcoin Core v29.0
- [x] Bitcoin Core v28.4
- [x] Bitcoin Core v28.3
- [x] Bitcoin Core v28.2
- [x] Bitcoin Core v28.1
- [x] Bitcoin Core v28.0
- [x] Bitcoin Core v27.2
- [x] Bitcoin Core v27.1
- [x] Bitcoin Core v27.0
- [x] Bitcoin Core v26.2
- [x] Bitcoin Core v26.1
- [x] Bitcoin Core v26.0
- [x] Bitcoin Core v25.2
- [x] Bitcoin Core v25.1
- [x] Bitcoin Core v25.0
- [x] Bitcoin Core v24.2
- [x] Bitcoin Core v24.1
- [x] Bitcoin Core v24.0.1
- [x] Bitcoin Core v24.0
- [x] Bitcoin Core v23.2
- [x] Bitcoin Core v23.1
- [x] Bitcoin Core v23.0
- [x] Bitcoin Core v22.1
- [x] Bitcoin Core v22.0
- [x] Bitcoin Core v0.21.2
- [x] Bitcoin Core v0.21.1
- [x] Bitcoin Core v0.21.0
- [x] Bitcoin Core v0.20.2
- [x] Bitcoin Core v0.20.1
- [x] Bitcoin Core v0.20.0
- [x] Bitcoin Core v0.19.2
- [x] Bitcoin Core v0.19.1
- [x] Bitcoin Core v0.19.0.1
- [x] Bitcoin Core v0.19.0
- [x] Bitcoin Core v0.18.1
- [x] Bitcoin Core v0.18.0
- [x] Bitcoin Core v0.17.2
- [x] Bitcoin Core v0.17.1
- [x] Bitcoin Core v0.17.0.1
- [x] Bitcoin Core v0.17.0
- [x] Bitcoin Core v0.16.3
- [x] Bitcoin Core v0.16.2
- [x] Bitcoin Core v0.16.1
- [x] Bitcoin Core v0.16.0
- [x] Bitcoin Core v0.15.2
- [x] Bitcoin Core v0.15.1
- [x] Bitcoin Core v0.15.0.1
- [x] Bitcoin Core v0.15.0
- [x] Bitcoin Core v0.14.3
- [x] Bitcoin Core v0.14.2
- [x] Bitcoin Core v0.14.1
- [x] Bitcoin Core v0.14.0
- [x] Bitcoin Core v0.13.2
- [x] Bitcoin Core v0.13.1
- [x] Bitcoin Core v0.13.0
- [x] Bitcoin Core v0.12.1
- [x] Bitcoin Core v0.12.0
- [x] Bitcoin Core v0.11.3
- [x] Bitcoin Core v0.11.2
- [x] Bitcoin Core v0.11.1
- [x] Bitcoin Core v0.11.0
- [x] Bitcoin Core v0.10.4
- [x] Bitcoin Core v0.10.3
- [x] Bitcoin Core v0.10.2
- [x] Bitcoin Core v0.10.1
- [x] Bitcoin Core v0.10.0
- [x] Bitcoin Core v0.9.5
- [x] Bitcoin Core v0.9.4
- [x] Bitcoin Core v0.9.3
- [x] Bitcoin Core v0.9.2.1
- [x] Bitcoin Core v0.9.2
- [x] Bitcoin Core v0.9.1
- [x] Bitcoin Core v0.9.0
- [x] Bitcoin Core v0.8.6
- [x] Bitcoin Core v0.8.5
- [x] Bitcoin Core v0.8.4
- [x] Bitcoin Core v0.8.3
- [x] Bitcoin Core v0.8.2
- [x] Bitcoin Core v0.8.1
- [x] Bitcoin Core v0.8.0
- [x] Bitcoin Core v0.7.2
- [x] Bitcoin Core v0.7.1
- [x] Bitcoin Core v0.7.0
- [x] Bitcoin Core v0.6.3
- [x] Bitcoin Core v0.6.2
- [x] Bitcoin Core v0.6.1
- [x] Bitcoin Core v0.6.0
- [x] Bitcoin Core v0.5.3
- [x] Bitcoin Core v0.5.2
- [x] Bitcoin Core v0.5.1
- [x] Bitcoin Core v0.5.0
- [x] Bitcoin Core v0.4.0
- [x] Bitcoin Core v0.3.24
- [x] Bitcoin Core v0.3.23
- [x] Bitcoin Core v0.3.22
- [x] Bitcoin Core v0.3.21
- [x] Bitcoin Core v0.3.20.2
- [x] Bitcoin Core v0.3.20.1
- [x] Bitcoin Core v0.3.20
- [x] Bitcoin Core v0.3.19
- [x] Bitcoin Core v0.3.18
- [x] Bitcoin Core v0.3.17
- [x] Bitcoin Core v0.3.15
- [x] Bitcoin Core v0.3.14
- [x] Bitcoin Core v0.3.13
- [x] Bitcoin Core v0.3.12
- [x] Bitcoin Core v0.3.10
- [x] Bitcoin Core v0.3.8
- [x] Bitcoin Core v0.3.7
- [x] Bitcoin Core v0.3.6
- [x] Bitcoin Core v0.3.3
- [x] Bitcoin Core v0.3.2
- [x] Bitcoin Core v0.3.1
- [x] Bitcoin Core v0.3.0
- [x] Bitcoin Core v0.2.13
- [x] Bitcoin Core v0.2.12
- [x] Bitcoin Core v0.2.11
- [x] Bitcoin Core v0.2.10
- [x] Bitcoin Core v0.2.9
- [x] Bitcoin Core v0.2.8
- [x] Bitcoin Core v0.2.7
- [x] Bitcoin Core v0.2.6
- [x] Bitcoin Core v0.2.5
- [x] Bitcoin Core v0.2.4
- [x] Bitcoin Core v0.2.2
- [x] Bitcoin Core v0.2.0
- [x] Bitcoin Core v0.1.5

---

# Custom Forks

- [x] [SV2-IPC Patch by @Sjors](https://github.com/Sjors/bitcoin/tree/sv2-ipc) - v28.99.0
- [x] [SV2 Patch by @Sjors](https://github.com/Sjors/bitcoin/tree/sv2) - v25.99.0
- [x] [MutinyNet Patch by @benthecarman](https://github.com/benthecarman/bitcoin) - v24.99.0
- [x] [CPUnet Patch by @braidpool](https://github.com/braidpool/bitcoin/tree/cpunet) - v27.99.0
- [x] [Bitcoin FIBRE by @bitcoinfibre](https://github.com/bitcoinfibre/bitcoinfibre) - mapped Core release `30.0` (`v30.0-fibre`); release metadata is configurable in `forks/bitcoinfibre/default.nix`
