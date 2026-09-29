# VM.md — running the whole archive as one nixOS VM per version

Goal: every one of the 137 Bitcoin Core releases under `core/` (v31.1 →
v0.1.5) runs as its own minimal nixOS VM, all on a single bare-metal
x86-64 host with KVM. Built by `vm/all.nix`, deployed by the
`deploy-fleet.sh` it generates.

This is the *deployment* plan; the *verification* harness is
`tests/vm/` (one big VM, 137 check scripts, proves every binary works).

## Tiers

Every version gets a tier that decides how its VM node behaves on
mainnet:

| Tier | Versions | Count | Behavior |
|---|---|---|---|
| `snapshot-935000` | 31.0–31.1 | 2 | pruned; UTXO snapshot via `loadtxoutset`; follows the live chain |
| `snapshot-910000` | 30.0–30.3 | 4 | same, older snapshot |
| `snapshot-880000` | 29.0–29.4 | 5 | same, older snapshot |
| `snapshot-840000` | 28.0–28.4 | 5 | same, older snapshot |
| `ibd` | 0.13.0–27.2 | 49 | pruned (550 MiB) full IBD with the era's built-in `-assumevalid` checkpoint |
| `archival-pruned` | 0.11.0–0.12.1 | 6 | pruned IBD; stops at the segwit activation (block 481,824, 2017) — the last block these versions can validate |
| `archival` | 0.5.0–0.10.4 | 30 | unpruned IBD to the era ceiling (BIP-34/BIP-16/BIP-66 activation points), then idles |
| `gui` | 0.2.0–0.4.0 | 35 | the wx2.9 GUI binary is installed, no daemon (0.2.x–0.4.x is a single GUI process, needs an X display — see the smoke test) |
| `src` | 0.1.5 | 1 | the source-only artifact; the tarball content is installed, nothing runs |

136 of the 137 VMs (all but 0.1.5) boot a nixOS system; 101 run a
`bitcoind` service (every version from 0.5.0 up).

## UTXO snapshots (the 28.0+ tier)

Source: the community-run jaonoctus snapshot infrastructure
(https://jaonoctus.dev, files at https://files-vps02.jaonoctus.dev/).
Assume-UTXO raw dumps, generated with `dumptxoutset`; each is
loadable only by Core versions at or above the "since" floor because
the on-disk UTXO serialization format changed across eras.

| File | Height | Since | Best block (verification target) | Size |
|---|---|---|---|---|
| `utxo-840000.dat` | 840,000 | v28.0 | `0000000000000000000320283a032748cef8227873ff4872689bf23f1cda83a5` | 9,772,098,907 B (9.10 GiB) |
| `utxo-880000.dat` | 880,000 | v29.0 | `000000000000000000010b17283c3c400507969a9c2afd1dcf2082ec5cca2880` | ~9 GiB |
| `utxo-910000.dat` | 910,000 | v30.0 | `0000000000000000000108970acb9522ffd516eae17acddcb1bd16469194a821` | ~9 GiB |
| `utxo-935000.dat` | 935,000 | v31.0 | `0000000000000000000147034958af1652b2b91bba607beacc5e72a56f0fb5ee` | ~8.7 GiB |

URLs are `https://files-vps02.jaonoctus.dev/<file>` (recorded in
`fleet.json` per snapshot-tier version).

Flow per snapshot-tier VM (executed by `deploy-fleet.sh snapshot`):

1. boot the VM, wait for the era's `bitcoin-cli` RPC;
2. download the `.dat` to the host (cached in `/var/lib/btc-fleet/snap/`),
   stream it into the guest's datadir over ssh;
3. `bitcoin-cli loadtxoutset <datfile>`;
4. verify: `gettxoutsetinfo`.bestblock must equal the snapshot's best
   block (table above) — unambiguous, no byte-order ambiguity;
5. delete the `.dat` from the guest (Core docs: safe once loaded;
   saves ~9 GiB × 16 VMs).

`-prune=1100` on this tier: Core's assumeutxo docs require the prune
target to be at least 1100 MiB while a snapshot is being loaded (two
chainstates coexist).

## Per-tier flags (the service each VM runs)

All: `-server -datadir=/var/lib/btc-<version> -rpcbind=127.0.0.1
-rpcport=<18443+idx> -rpcuser=archive -rpcpassword=archivepass`, where
`idx` is the version's position in the sorted list (so each VM has a
stable, collision-free port; the host forwards each port to one VM via
qemu user-net `hostfwd`).

- `archival` (0.5.0–0.10.4): no `-prune` (unknown before 0.11).
- `archival-pruned` (0.11.0–0.12.1): `-prune=550`.
- `ibd` (0.13.0–27.2): `-prune=550`.
- `snapshot-*` (28.0–31.1): `-prune=1100`.

Deliberately *no* `-regtest` anywhere in the fleet: the point is
mainnet. Every flag is one the specific binary knows; pre-0.13
binaries only warn on unknown options, later ones exit.

## Which eras actually follow the live chain (honesty table)

| Era | Can reach today's tip? | Stalls at | Why |
|---|---|---|---|
| 28.0–31.1 | yes, within hours | — | snapshot + IBD from ~840k–935k |
| 22.0–27.2 | yes, over weeks | — | full pruned IBD, modern protocol (pver 70016) |
| 0.15.0–0.21.2 | probably | — | pver 70016, full consensus rules; **[UNVERIFIED]** whether 2026 peers still accept them |
| 0.13.0–0.14.x | at risk | — | pver 70015; modern Core may have raised its minimum below-rejection threshold **([UNVERIFIED])**; plus hardcoded 2011–2016 DNS seeds may be dead |
| 0.11.0–0.12.1 | no, by design | block 481,824 (2017-08, segwit activation) | pre-segwit consensus rules |
| 0.9.0–0.10.4 | no, by design | block 363,720 (2016-08, BIP-66 activation) | BIP-66 not implemented |
| 0.5.0–0.8.6 | no, by design | the BIP-34/BIP-16-era activation points (2011–2012) | pre-BIP-34/16 consensus **([UNVERIFIED] per minor)** |

The stall points are *correct behavior*, not breakage — these are
archival nodes that prove the historical binaries run and their RPC
works. 0.13–0.17 VMs that cannot discover peers (dead DNS seeds) can
be pointed at a modern relay manually (`-addr`/`-connect` via the VM's
ssh); until then they idle at block 0, RPC healthy.

## Minimum host requirements

| Resource | Minimum | Recommended | Basis |
|---|---|---|---|
| CPU | 24 vCPU x86-64, KVM | 32–64 cores | [ESTIMATE] 136 guests × 1–2 vCPU (oversubscription is fine at steady state; simultaneous IBD saturates a 24-core box for a while) |
| RAM | 128 GiB | 256 GiB | [ESTIMATE] allocation: 36 guests × 1 GiB + 65 guests × 2 GiB = 166 GiB worst case; idle guests use a few hundred MiB; a 64 GiB host works with `deploy-fleet.sh --wave 24` |
| Disk (NVMe) | 3 TiB | 4–5 TiB | steady ≈ 1.8 TiB [ESTIMATE]: 65 mainnet-following nodes × ~15 GiB (chainstate ~11–12 GiB per node — spark.money, early 2025; + pruned blocks + index + OS) + 36 archival nodes (0.9/0.10 unpruned to ~35–45 GiB each, 0.5–0.8 smaller) + 35 gui + 1 src + host |
| Network | ~0.7 TB download per IBD VM | — | mainnet chain ≈ 665 GB (spark.money 2026-06-26) / 770 GB (ycharts); 49 `ibd` VMs ⇒ ~33 TB fleet-wide over their catch-up window; snapshot VMs only need ~9 GiB each |
| Software | qemu-system-x86_64, jq, curl, openssh-client | | host side |

## Build & deploy

```
# on the build host (era checkouts available — same env vars as tests/vm):
NIXPKGS_16_09=… NIXPKGS_20_09=… NIXPKGS_23_11=… NIXPKGS_25_05=… \
  nix-build vm/all.nix -A fleet            # builds 137 images + the bundle
# or iterate on one:
nix-build vm/all.nix -A images.31.1

# on the target host:
nix-store --realise /nix/store/…-bitcoin-core-archive-fleet
result/bin/deploy-fleet.sh deploy       # boot all 137 VMs
result/bin/deploy-fleet.sh snapshot     # load the 16 UTXO snapshots
result/bin/deploy-fleet.sh status       # per-version tier + block height
result/bin/deploy-fleet.sh stop
```

The fleet bundle contains `deploy-fleet.sh` and `fleet.json`
(version → tier, ports, image store path, snapshot spec).
Images are qcow2 (sparse); first `deploy` copies them into
`/var/lib/btc-fleet/vm/<version>/`.

Verified live-boot facts (single-group smoke, 2026-09-29): guests
authenticate root over the forwarded ssh port with the bundle's
`keys/id_ed25519`. The image sshd runs with `StrictModes no` on
purpose — authorized keys live at `/etc/ssh/authorized_keys`, a
`/nix/store` symlink virtfs-shared from the HOST, and a group-writable
host store (the common `root:nixbld 1775` multi-user layout) makes
OpenSSH's StrictModes ancestor walk refuse the key ("bad ownership or
modes for directory /nix/store"). Keep `-rpcuser` different from
`-rpcpassword`: pre-0.10 binaries abort at `StartRPCThreads` when the
two are equal on mainnet (the regtest VM tests skip that check).

## Known risks

- **jaonoctus retention**: the `.dat` files are community-hosted. Once
  loaded they are gone from the picture (deleted from the guest, kept
  on the host in `/var/lib/btc-fleet/snap/`); if the HTTP host ever
  goes away, the pinned per-height URLs are the only re-fetch path.
- **0.13–0.17 peer discovery**: pre-2020 DNS seed lists; see honesty
  table. Remedy is manual and per-VM.
- **pver floor**: whether 2026-era Core still peers with pver-70015
  (0.13/0.14) nodes is unverified; affects only those 8 VMs.
- **RAM waves**: on a ≤128 GiB host, deploy in waves
  (`deploy-fleet.sh deploy --wave 24`) and snapshot after each wave.
- **era ceiling VMs look "stuck"**: a 0.9.x node at block 363,720 is
  *correct*; do not chase it as a failure.
