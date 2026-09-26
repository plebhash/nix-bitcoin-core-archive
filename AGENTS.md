# AGENTS.md — notes for agents working on nix-bitcoin-core-archive

> **Local environment?** If an `AGENTS_CUSTOM.md` exists at the repo root,
> read it first. It is git-ignored and holds the specifics of the local
> development environment (build hosts, nixpkgs checkouts, helper scripts,
> local commit conventions) that supplement the generic guidance below.

Nix derivations for old Bitcoin Core releases live in
`core/<version>/default.nix`, forks in `forks/`. Each version dir is
self-contained: it imports `<nixpkgs>` itself, so the *only* thing that
varies between eras is which nixpkgs you evaluate it against
(`NIX_PATH`).

## Platform

The core assumption of this project is that target architecture and
kernel support remains limited to **x86-64 Linux** — no darwin, no
arm64/aarch64, nothing else. The derivations are only tested on Linux.

## Which nixpkgs per era (this is the load-bearing table)

| Versions | nixpkgs | why |
|---|---|---|
| v22.0 – v28.4 | 23.11 | era-appropriate boost/qt; 25–28.4 pin `core/_deps/miniupnpc-2.2.2.nix` |
| v29.0 – v31.1 | 25.05 | needs `libsodium` as an explicit buildInput (see leak below) |
| v0.13.0 – v0.21.2 | 20.09 | last channel where qt4-era deps line up |
| v0.9.0 – v0.12.1 | **16.09** | 0.9.x `rpcserver.cpp` uses the 2-arg asio `basic_socket_acceptor<Protocol, Service>`, removed in boost ≥ 1.65; 16.09 ships boost 1.60 |
| v0.1.5 – v0.8.6 | **16.09** + gcc49 | C++03 code + `wxGTK29` (0.2.x–0.4.x GUI era); the derivations override `stdenv` to `cc = pkgs.gcc49` (with `wx29`/`boost`/`db48` following it) — gcc-5's stricter template deduction breaks this code (e.g. `serialize.h` `min()`); newer channels' wx2.9 headers require C++11 |

Launching a build: point `NIX_PATH=nixpkgs=<era checkout>` at the era's
nixpkgs source tree and `nix-build core/<v>/default.nix` (or a
batch script, see AGENTS_CUSTOM.md). If the `NIX_PATH` dir does not
exist, nix silently falls back to whatever `<nixpkgs>` resolves to and
builds with the wrong toolchain — always verify the path exists. The
first build of a new era pays a 1–2 h dependency-chain build
(wx29/boost/db48/openssl from source) — later versions are incremental.

## Nix quirks that will bite you

- **mkDerivation name**: nixpkgs ≤ 18.09 do NOT compose `name` from
  `pname` + `version`. Pre-0.13 derivations therefore carry an explicit
  `name = "bitcoind-${version}";` — keep it when touching those files
  (same for the `core/_deps/*.nix` helpers).
- **pkg-config naming**: old nixpkgs call it `pkgconfig`. Headers use
  `(pkgs."pkg-config" or pkgs.pkgconfig)` — preserve that form.
- `nix-instantiate --eval` prints `<CODE>` for everything without
  `--strict`; always pass `--eval --strict`.
- `nix-build` without `--add-root` prints GC warnings; ad-hoc builds may
  get collected by a later `nix-collect-garbage` (re-`ls -d
  /nix/store/*-bitcoind-<v>` after a GC to check).
- **Nix string backslashes**: in a `.nix` string literal, write sed
  backreferences as `\\(` / `\\1` (doubled). A single `\(` is eaten
  by the string parser and the sed arrives with the pattern broken —
  it silently stops matching and the build fails deep in the source
  (verified in the generated drv). Every sed in `core/` follows the
  doubled-backslash form; keep it.

## Per-era source/build fixes (already in the derivations — why)

- **Makefile era (0.1.5–0.8.6)**: builds with
  `CXX='${stdenv.cc}/bin/g++ -std=gnu++03 -fpermissive'`. C++11
  narrowing is a hard error in this code; `-fpermissive` alone is not
  enough. `patchPhase` rewrites hardcoded `g++` → `$(CXX)` in
  `makefile.unix`. The 0.2.x–0.4.x GUI binary is `bitcoin` (wx2.9,
  single GUI+node process; needs an X display); 0.5.x–0.8.6 are
  daemon-only.
- **GUI era (0.2.x–0.4.x) buildPhase seds** (run after `mkdir -p obj
  obj/nogui obj/test cryptopp/obj` — the GitHub tag tarballs omit the
  empty obj dirs the makefiles assume):
  - glibc ≥ 2.20 defines `htons`/`htonl` as statement-expression
    macros; global-scope `static const ... = htons(...)` initializers
    are rejected by gcc → sed to `__builtin_bswap16/32`. 0.2.10–0.2.12
    moved the macro into `#define DEFAULT_PORT htons(8333)` → those
    three carry extra bare-token seds for all four bswap names.
  - `min(nSize - i, 1 + 4999999 / sizeof(T))` in serialize.h fails
    template deduction (unsigned int vs unsigned long) → cast the
    second arg.
  - 0.2.x only: wx2.9 made `wxEvtHandler::AddPendingEvent` protected →
    sed to `wxPostEvent`. Three ordered seds: (a) the
    `pframeMain->GetEventHandler()->AddPendingEvent(e)` special case,
    (b) `X->AddPendingEvent(e)` with a NON-EMPTY identifier
    (`[a-zA-Z_][a-zA-Z_]*` — an empty `[a-zA-Z_]*` match corrupts
    `X->GetEventHandler()->AddPendingEvent(e)` into
    `X->GetEventHandler()wxPostEvent(, e)`), (c) bare `AddPendingEvent(e)`
    → `wxPostEvent(this, e)`.
  - 0.2.0: `wxGetOsDescription().mb_str()` → append `.data()`
    (wxScopedCharBuffer is non-copyable in wx2.9, gcc rejects the
    pass-by-value).
  - 0.2.x: the 2009 makefile links the monolithic `wx_gtk2ud-2.8`;
    sed it to the full nixpkgs wx2.9 split set —
    `xrc html richtext qa adv core baseu_xml baseu_net baseu` (core
    alone misses wxHtml + wxRichText symbols).
  - 0.3.1–0.3.3: `native_file_string().c_str()` → `string().c_str()`
    (boost 1.60 removed native_file_string).
  - 0.3.6–0.3.13: append `-l dl` to the link (plugin loading via
    dlopen; libdl invisible to the old makefiles).
  - 0.3.21–0.3.24/0.4.0: delete the `USE_UPNP:=0` makefile line
    (same ifdef-ignores-value trap as 0.5.0–0.8.6 below).
  - `-Wl,-Bstatic` (static boost/db48 link) finds no static archives in
    nixpkgs → sed the flag into the `-L` list of the nix libs.
- **0.4.0**: `ifdef USE_UPNP` + `USE_UPNP:=0` still enables UPnP
  (ifdef ignores the value) → delete the `USE_UPNP:=0` line.
- **0.5.0–0.8.6**: `USE_UPNP=-` on the make command line (the makefile
  `USE_UPNP:=0` still *defines* the macro, so `#ifdef USE_UPNP` in
  net.cpp demanded miniupnpc headers with no link flag).
- **0.8.0–0.8.6**: CXX must stay a single token — the leveldb
  sub-make (`MAKEOVERRIDES =`, invoked with `CXX=$(CXX)`) chokes on
  spaces → `CXX='g++' CXXFLAGS='-std=gnu++03 -fpermissive'`.
- **0.1.5** is a source-only artifact: `installPhase` copies
  `$sourceRoot` to `$out/src` after `cd $NIX_BUILD_TOP` (phases run
  inside `$sourceRoot`; the `sourceRoot` env var is relative).
- **0.9–0.12 (16.09)**: `LDFLAGS=-ldl` in configureFlags (configure
  never finds libdl in the nix env); explicit `name` (above).
- **0.13–0.15.1 (20.09)**: `postUnpack` seds make the
  `miner.h`/`txmempool.h` comparators and `UseDescendantScore` `const` —
  boost ≥ 1.69 multi_index demands const comparators; upstream fixed
  this in v0.15.2, so 0.15.2+ do not need it.
- **0.9–0.12 miniupnpc**: vendored `core/_deps/miniupnpc-1.7.nix` (old
  6-arg `upnpDiscover` / 5-arg `UPNP_GetValidIGD` API);
  `core/_deps/openssl-1.0.2.nix` for the pre-1.1 BIGNUM API (0.2–0.8)
- **24.1 (23.11)**: `src/chainparamsbase.h` uses `uint16_t` with only
  `<memory>`/`<string>` included; gcc-12+ no longer transitively
  pulls in `<cstdint>` → patchPhase seds `#include <cstdint>` in
  (anchored on the `<memory>` include). 24.0 survived on an earlier
  header order; do not "clean up" this patch.

## Host-library leaks (the classic silent failure)

A binary that passes `bitcoind -version` **on the build machine** but
fails everywhere else usually linked a host `/usr/lib` library
(29.0–31.1 leaked `/usr/lib/libsodium.so.26`). Detection:

```
readelf -d <store>/bin/bitcoind | grep -E "RUNPATH|RPATH"   # missing dep?
ldd <store>/bin/bitcoind | grep -E "not found|/usr/lib"     # host leak?
```

Modern nixpkgs binaries carry the nix glibc loader as interpreter,
which does not search `/usr/lib`. Fix = add the library to
`buildInputs`; never rely on host paths.

## Store GC recovery (outputs vanish, registrations stay)

If a store is not GC-rooted (see AGENTS_CUSTOM.md for the local
situation), `nix-collect-garbage` can delete built outputs while the
DB keeps their registrations — nix then reports "nothing to build" for
those derivations. Recovery:

1. Detect: for each `core/<v>` check `ls -d /nix/store/*-bitcoind-<v>`
   (plus `*-bitcoin-src-<v>` for 0.1.5).
2. Clear stale registrations: `nix-store --delete <output-path>`
   (the path from `nix-store -q <drv>`; it may not exist on disk —
   that is exactly the point).
3. Rebuild with the era's nixpkgs.

Everything is reproducible from the repo, so this costs build time
only, not data. Real protection = one store path per line in
`/nix/var/nix/gcroots/<name>` (needs root) or a user profile.

## Commits

- Progressive, per-era commits with a body explaining the era's
  nixpkgs pin and the source-level fixes; only commit versions that
  build and pass the era's smoke check (see the ladder below).
- Local author conventions (who signs, what identity to commit as)
  live in AGENTS_CUSTOM.md; otherwise follow the existing git history.
- NEVER commit private keys or credentials. The fleet ssh keypair
  (`fleet-keys/`) is git-ignored and generated locally (`ssh-keygen -t
  ed25519 -N "" -C fleet -f fleet-keys/id_ed25519`); `vm/all.nix`
  reads it via `FLEET_KEYS` (default `../fleet-keys` = `<repo>/fleet-keys`). If a key ever
  lands in history, rewrite the commits before anything is pushed —
  history here is local-only (the build host is a tar mirror, not a
  git push).

## Verification ladder (fast → thorough)

1. `nix-instantiate --parse core/<v>/default.nix` (syntax)
2. `nix-build core/<v>/default.nix` + era-appropriate smoke check:
   `bitcoind -version` (v0.13.0+), startup marker (0.5.0–0.12.1, no
   `-version` flag yet), headless GUI startup (0.2.x–0.4.x)
3. run a node: `bitcoind -regtest -printtoconsole` (Ctrl-C) — works
   across v0.9–v31.1
4. `tests/vm/` full-VM run: a nixOS VM with every derivation installed,
   per-version check suite (see `tests/vm/default.nix` +
   `run-vm-test.sh`) — the full-integration gate. The harness locates
   the era nixpkgs checkouts via the `NIXPKGS_16_09`, `NIXPKGS_20_09`,
   `NIXPKGS_23_11`, `NIXPKGS_25_05` environment variables (absolute
   paths to each era's source tree); `NIXPKGS_25_05` also serves as
   the VM's own nixpkgs generation.
