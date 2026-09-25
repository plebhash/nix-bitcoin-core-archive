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

## limitations

- arch: `x86-64` only
- kernel: `linux` only

## instructions

Just `cd` into the directory of the chosen version, and then do a `nix-build`. The build artifacts will be placed at `result`. For example, if you want to run `0.21.0`:
```
$ cd core/0.21.0
$ nix-build
$ ls result/bin
bitcoin-cli  bitcoind  bitcoin-qt  bitcoin-tx  bitcoin-wallet
```

## data directory compatibility

Bitcoin Core's on-disk format — the `blocks/index` LevelDB block index,
the `chainstate` LevelDB coin database (and, pre-v0.8.0, the Berkeley
DB databases) — is **not stable across releases**. Two versions can
share a `~/.bitcoin` (or `-datadir`) only if they fall in the same
format group below.

`tools/extract-compat.py` derives each release's on-disk fingerprint
from the upstream git tags (full output: `tools/compat.tsv`). A group
is a maximal run of consecutive versions sharing: the DB engine, the
coin key prefix, the coin-serialization fingerprint, the
block-index-serialization fingerprint, and the block-index location.

| group | versions | engine | coin key | obfuscated | coin fp | block-index fp |
|-------|----------|--------|----------|------------|---------|----------------|
| 1 | 0.1.5 | Berkeley DB | – | – | – | 03fae236610b |
| 2 | 0.2.0 – 0.3.10 | Berkeley DB | – | – | – | 67e229a2d7f0 |
| 3 | 0.3.12 – 0.3.21 | Berkeley DB | – | – | – | 9a6bbd37b409 |
| 4 | 0.3.22 – 0.7.2 | Berkeley DB | – | – | – | c0ee0577f665 |
| 5 | 0.8.0 – 0.8.1 | LevelDB | `c` | no | 430368e4ee74 | 7becec847b30 |
| 6 | 0.8.2 – 0.8.6 | LevelDB | `c` | no | 430368e4ee74 | 7023acece663 |
| 7 | 0.9.0 – 0.9.5 | LevelDB | `c` | no | 430368e4ee74 | 341fc3f7b8bf |
| 8 | 0.10.0 – 0.11.3 | LevelDB | `c` | no | 8d3532e655d3 | c2426086e0f5 |
| 9 | 0.12.0 – 0.13.2 | LevelDB | `c` | yes | 8d3532e655d3 | c2426086e0f5 |
| 10 | 0.14.0 – 0.14.3 | LevelDB | `c` | yes | 27c7aac6e8e2 | 5bde826b4924 |
| 11 | 0.15.0 – 0.15.2 | LevelDB | `C` | yes | fa3980c4d841 | 5ebe11e1989b |
| 12 | 0.16.0 – 0.16.3 | LevelDB | `C` | yes | dead42387f2f | 5ebe11e1989b |
| 13 | 0.17.0 – 0.19.2 | LevelDB | `C` | yes | e8f9dbd0bf57 | f53eb49b123a |
| 14 | 0.20.0 – 22.1 | LevelDB | `C` | yes | e447123e2346 | 86541ec2278e |
| 15 | 23.0 – 25.2 | LevelDB | `C` | yes | e447123e2346 | 728cd8a091c8 |
| 16 | 26.0 – 31.1 | LevelDB | `C` | yes | e447123e2346 | 0419e90a5ff3 |

Fingerprint columns are `sha1[:12]` of the normalized serialization
code (group 11 vs 12, 13 vs 14 etc. are split by code changes that may
still produce identical bytes — see caveat below).

**Reading the table**

- **Within a group**: safe to share a data directory across any two
  versions in the group (e.g. run 0.19.2 on a datadir written by
  0.17.0, or 31.1 on one written by 26.0).
- **Across groups**: incompatible — the other version cannot
  reliably read the databases; use a separate datadir (or start
  fresh / reindex).
- **Berkeley DB era (groups 1–4)**: four mutually incompatible BDB
  sub-eras; pre-v0.8.0 datadirs are never portable forward.
- **coin key `c` → `C` at v0.15.0** and **value obfuscation at
  v0.12.0** are the two headline on-disk format changes of the
  LevelDB era.
- **regtest**: from v0.9.0 through v31.1 all versions assert the same
  regtest genesis (`0f9188f1…e2206`), so regtest chain *data* is
  consistent across the whole range; the on-disk groups above still
  determine which pairs can open the same regtest datadir.
  v0.1.5 – v0.8.6 have no `-regtest` network.
- **Caveat**: the split is *conservative*. A changed fingerprint means
  the serialization *code* changed, not necessarily the bytes on disk
  (e.g. v0.17.0's `VarIntMode::NONNEGATIVE_SIGNED` only alters
  encoding of negative values, which block fields never hold). The
  table is therefore a safe superset of incompatible pairs; empirical
  swap-testing (see `tests/vm/`) is the final arbiter for boundary
  groups that may in fact be byte-compatible.


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
