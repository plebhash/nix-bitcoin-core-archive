# AGENTS.md — operational notes for nix-bitcoin-core-archive

Derivations for old Bitcoin Core releases live in `core/<version>/default.nix`,
forks in `forks/`. Each version dir is self-contained: it imports
`<nixpkgs>` itself, so the *only* thing that varies between eras is which
nixpkgs you evaluate it against (`NIX_PATH`).

## Build host (the "slave")

Heavy builds do NOT run on the omarchy desktop machine (4-core i7-4770,
the user's daily system — keep it untouched). They run on the build host:

- Reached over ssh on your LAN (address, account and credentials are
  local environment specifics — keep them out of the repo).
- Repo mirror: a checkout of this repo on the build host.
- Mirror it after local edits (sync the working tree) — run it before
  every remote build launch.
- Nixpkgs source checkouts for each era live on the build host (one
  checkout per era; see the era table below).
- Batch builder: `~/src/build-era.sh NAME NIXPKGS_DIR VERSION...` —
  instantiates, builds, then runs `bitcoind -version` per version;
  logs to `batch-NAME-build.log`, GC-roots results in
  `batch-NAME-build.log.roots`.
- Quick status: `bash /tmp/listbuilt.sh` (built versions) and
  `tail -1 batch-NAME-build.log` per batch.

If you do **not** have the slave, the same commands work on the local
machine — just expect single-digit-cores speed and do not launch more
than one batch at a time.

## Which nixpkgs per era (this is the load-bearing table)

| Versions | nixpkgs | why |
|---|---|---|
| v22.0 – v28.4 | 23.11 | era-appropriate boost/qt; 25–28.4 pin `core/_deps/miniupnpc-2.2.2.nix` |
| v29.0 – v31.1 | 25.05 | needs `libsodium` as an explicit buildInput (see leak below) |
| v0.13.0 – v0.21.2 | 20.09 | last channel where qt4-era deps line up |
| v0.9.0 – v0.12.1 | **16.09** | 0.9.x `rpcserver.cpp` uses the 2-arg asio `basic_socket_acceptor<Protocol, Service>`, removed in boost ≥ 1.65; 16.09 ships boost 1.60 |
| v0.1.5 – v0.8.6 | **16.09** + gcc49 | C++03 code + `wxGTK29` (0.2.x–0.4.x GUI era); the derivations override `stdenv` to `cc = pkgs.gcc49` (with `wx29`/`boost`/`db48` following it) — gcc-5's stricter template deduction breaks this code (e.g. `serialize.h` `min()`); newer channels' wx2.9 headers require C++11 |

Launch pattern:

```
ssh <build-host> '
  nohup bash -c "bash ~/src/build-era.sh E4r7 <nixpkgs-16.09-checkout> 0.9.0 0.9.1 ..." \
    > ~/src/era-E4r7.log 2>&1 &
  echo "PID: $!"'
```

The script exports `NIX_PATH` itself. 4–6 concurrent batches saturate the
slave; the first run of a new era pays a 1–2 h dependency-chain build
(wx29/boost/db48/openssl from source) — later versions are incremental.

## Nix quirks that will bite you

- nix 2.3.5 with the experimental CLI disabled: use legacy
  `nix-build` / `nix-instantiate`, not `nix build`/`nix eval`.
- `nix-instantiate --eval` prints `<CODE>` for everything without
  `--strict`; always pass `--eval --strict`.
- **mkDerivation name**: nixpkgs ≤ 18.09 do NOT compose `name` from
  `pname` + `version`. Pre-0.13 derivations therefore carry an explicit
  `name = "bitcoind-${version}";` — keep it when touching those files
  (same for the `core/_deps/*.nix` helpers).
- **pkg-config naming**: old nixpkgs call it `pkgconfig`. Headers use
  `(pkgs."pkg-config" or pkgs.pkgconfig)` — preserve that form.
- `nix-build` without `--add-root` prints GC warnings; the batch script
  roots results, ad-hoc builds may get collected (re-`ls -d
  /nix/store/*-bitcoind-<v>` after GC to check).

## Per-era source/build fixes (already in the derivations — why)

- **Makefile era (0.1.5–0.8.6)**: builds with
  `CXX='${stdenv.cc}/bin/g++ -std=gnu++03 -fpermissive'`. C++11
  narrowing is a hard error in this code; `-fpermissive` alone is not
  enough. `patchPhase` rewrites hardcoded `g++` → `$(CXX)` in
  `makefile.unix`. The 0.2.x–0.4.x GUI binary is `bitcoin` (wx2.9,
  single GUI+node process; run with `ssh -X`); 0.5.x–0.8.6 are
  daemon-only.
- **0.9–0.12 (16.09)**: `LDFLAGS=-ldl` in configureFlags (configure
  never finds libdl in the nix env); explicit `name` (above).
- **0.13–0.15.1 (20.09)**: `postUnpack` seds make the
  `miner.h`/`txmempool.h` comparators and `UseDescendantScore` `const` —
  boost ≥ 1.69 multi_index demands const comparators; upstream fixed
  this in v0.15.2, so 0.15.2+ do not need it.
- **0.9–0.12 miniupnpc**: vendored `core/_deps/miniupnpc-1.7.nix` (old
  6-arg `upnpDiscover` / 5-arg `UPNP_GetValidIGD` API);
  `core/_deps/openssl-1.0.2.nix` for the pre-1.1 BIGNUM API (0.2–0.8)
  and the "Detected LibreSSL" configure heuristic (0.9–0.12).

## Host-library leaks (the classic silent failure)

A binary that passes `bitcoind -version` **on the build host** but fails
everywhere else usually linked a host `/usr/lib` library (29.0–31.1
leaked `/usr/lib/libsodium.so.26`). Detection:

```
readelf -d <store>/bin/bitcoind | grep -E "RUNPATH|RPATH"   # missing dep?
ldd <store>/bin/bitcoind | grep -E "not found|/usr/lib"     # host leak?
```

Modern nixpkgs binaries carry the nix glibc loader as interpreter,
which does not search `/usr/lib`. Fix = add the library to
`buildInputs`; never rely on host paths.

## Misc operational gotchas

- `pkill -f "pattern"` over ssh kills your own remote shell when the
  pattern appears in the command line you sent. Use the bracket trick:
  `pkill -f "build-era.sh E4r[6]"`.
- The slave has no nixpkgs channel configured; never rely on
  `<nixpkgs>` resolving there except via the batch script's
  `NIX_PATH` export (or your own).
- Long ssh commands get auto-backgrounded by the tooling; that is fine —
  the batch itself is `nohup`'d and survives.

## Commits

- Author: `plebhash <plebhash@gmail.com>` (the user gpg-signs later;
  commit with `-c user.name=plebhash -c user.email=plebhash@gmail.com`).
- Progressive, per-era commits with a body explaining the era's
  nixpkgs pin and the source-level fixes; only commit versions that
  build and pass the `-version` smoke check.
- The nixOS VM harness (`tests/vm/`, driven by
  `tests/vm/run-vm-test.sh`) is the full-integration gate: it installs
  every derivation into one VM config and runs each binary. Run it
  before the final commit of an era if you can.

## Verification ladder (fast → thorough)

1. `nix-instantiate --parse core/<v>/default.nix` (syntax)
2. `nix-build core/<v>/default.nix` + `bitcoind -version`
3. run a node: `bitcoind -regtest -printtoconsole` (Ctrl-C) — works
   across v0.9–v31.1
4. `tests/vm/` full-VM run (all versions)
