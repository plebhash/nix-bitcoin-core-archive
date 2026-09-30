# Shared helpers for the archive's nixOS VM builders:
#   vm/all.nix   — the 137-version mainnet fleet (one VM per version)
#   vm/swap.nix  — the swap fleet (one VM per datadir-compat group)
#   tests/vm/    — the verification harness
#
# This file only defines; it evaluates the era nixpkgs generations
# (absolute checkout paths from environment variables), the
# core/<version>/ derivation set, the resource tiers, and the
# datadir-format compatibility groups (parsed from
# tools/compat.tsv). Builders import it:
#   common = import ./common.nix;              # from vm/
#   common = import ../../vm/common.nix;      # from tests/vm/
#
# Era env vars (set on the build host, see AGENTS_CUSTOM.md):
#   NIXPKGS_16_09, NIXPKGS_20_09, NIXPKGS_23_11, NIXPKGS_25_05
#
# The 25.05 generation doubles as the guest nixpkgs (its glibc runs
# binaries from every era; the older ones cannot run newer glibc).

let
  # Era nixpkgs arrives as the absolute path of a source tree in an
  # environment variable — the 20.09-era derivations only need a
  # stable pkgs object, and importing the checkout directly is what
  # core/*/default.nix expects.
  eraPath = var:
  let
    p = builtins.getEnv var;
  in
  assert p != "";
  assert builtins.pathExists p;
  p;

  pkgsRoot = eraPath "NIXPKGS_25_05";
  pkgs = import pkgsRoot { system = builtins.currentSystem; };
  lib = pkgs.lib;

  # Era nixpkgs checkouts (the derivation in core/<v> is evaluated with
  # the generation its era was built with — same mapping as tests/vm).
  eras = {
    "16.09" = import (eraPath "NIXPKGS_16_09") { system = builtins.currentSystem; };
    "20.09" = import (eraPath "NIXPKGS_20_09") { system = builtins.currentSystem; };
    "23.11" = import (eraPath "NIXPKGS_23_11") { system = builtins.currentSystem; };
    "25.05" = pkgs;
  };

  coreDir = ./../core;
  # readDir entry format differs between nix versions (string vs { type } set).
  isDirEntry = e:
    if builtins.isAttrs e then e.type == "directory" else e == "directory";
  versions = lib.sort (a: b: builtins.compareVersions a b < 0) (
    lib.filter (n: n != "_deps" && isDirEntry (builtins.readDir coreDir).${n})
    (builtins.attrNames (builtins.readDir coreDir))
  );

  eraPkg = version:
  let
    era =
    if lib.versionOlder version "0.13.0" then eras."16.09"   # 0.1.5-0.12.1
    else if lib.versionOlder version "22.0" then eras."20.09"  # 0.13.0-0.21.2
    else if lib.versionOlder version "29.0" then eras."23.11"  # 22.0-28.4
    else eras."25.05";                                       # 29.0-31.1
  in import ../core/${version}/default.nix { pkgs = era; };

  tierOf = version:
    if version == "0.1.5" then "src"
    else if lib.versionOlder version "0.5.0" then "gui"             # 0.2.x-0.4.x
    else if lib.versionOlder version "0.11.0" then "archival"       # 0.5.0-0.10.4
    else if lib.versionOlder version "0.13.0" then "archival-pruned" # 0.11.0-0.12.1
    else if lib.versionOlder version "28.0" then "ibd"              # 0.13.0-27.2
    else if lib.versionOlder version "29.0" then "snapshot-840000"  # 28.0-28.4
    else if lib.versionOlder version "30.0" then "snapshot-880000"  # 29.0-29.4
    else if lib.versionOlder version "31.0" then "snapshot-910000"  # 30.0-30.3
    else "snapshot-935000";                                        # 31.0-31.1

  resOf = tier:
    if tier == "src" || tier == "gui" then { diskMib = 2048; ramMib = 512; vcpu = 1; }
    else if tier == "archival" then { diskMib = 40960; ramMib = 1024; vcpu = 2; }
    else if tier == "archival-pruned" then { diskMib = 16384; ramMib = 1024; vcpu = 2; }
    else if lib.hasPrefix "snapshot" tier then { diskMib = 32768; ramMib = 2048; vcpu = 2; }
    else { diskMib = 16384; ramMib = 2048; vcpu = 2; };            # ibd

  # Fleet ssh keypair — disposable, fleet-only, and never in git:
  # <repo>/fleet-keys (git-ignored), generate at the repo root with
  #   ssh-keygen -t ed25519 -N "" -C fleet -f fleet-keys/id_ed25519
  # FLEET_KEYS=/path/to/keydir overrides the location.
  fleetKeyDir =
  let
    p = builtins.getEnv "FLEET_KEYS";
    d = if p != "" then p else ./../fleet-keys;
  in
  assert builtins.pathExists (d + "/id_ed25519")
    && builtins.pathExists (d + "/id_ed25519.pub");
  d;

  fleetPubKey = builtins.readFile (fleetKeyDir + "/id_ed25519.pub");

  # UTXO snapshot specs (jaonoctus; see VM.md for the best-block
  # table — THE TABLE IS AUTHORITATIVE; these values were once
  # transcribed truncated (60/62 chars), which made the post-load
  # bestblock comparison die after every ~9 GiB stream. The asserts
  # below refuse to evaluate a non-64-hex hash at all.)
  snapshotSpec = key:
  let
    bestBlock =
      if key == "840000" then "0000000000000000000320283a032748cef8227873ff4872689bf23f1cda83a5"
      else if key == "880000" then "000000000000000000010b17283c3c400507969a9c2afd1dcf2082ec5cca2880"
      else if key == "910000" then "0000000000000000000108970acb9522ffd516eae17acddcb1bd16469194a821"
      else "0000000000000000000147034958af1652b2b91bba607beacc5e72a56f0fb5ee";
  in
  assert builtins.stringLength bestBlock == 64;
  assert builtins.match "[0-9a-f]{64}" bestBlock != null;
  {
    file = "utxo-${key}.dat";
    url = "https://files-vps02.jaonoctus.dev/utxo-${key}.dat";
    inherit bestBlock;
  };

  # --- datadir-format compatibility groups ---------------------------
  # tools/compat.tsv (derived from the README "Data directory
  # compatibility" table) is ascending in version order; a new group
  # starts whenever one of the six fingerprint columns changes
  # (engine, coin key, obfuscation, coin fp, bidx fp, bidx location —
  # the row minus the version and regtest columns). Group numbers are
  # stable: row 1 is group 1 (0.1.5, source-only), so the fleet groups
  # are 2..N.
  compatRows =
  let
    lines = lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile ./../tools/compat.tsv));
  in
  lib.map (l: lib.splitString "\t" l) (lib.tail lines);

  groups =
  let
    gkey = row: builtins.concatStringsSep "\t" (lib.take 6 (lib.tail row));
    fold = acc: row:
    let
      v = builtins.elemAt row 0;
      k = gkey row;
    in
    if acc.key == null || acc.key != k
    then acc // {
      groups = acc.groups ++ [ { no = (lib.length acc.groups) + 1; engine = builtins.elemAt row 1; versions = [ v ]; } ];
      key = k;
    }
    else
    let
      lastNo = (lib.last acc.groups).no;
    in
    acc // { groups = lib.map (g: if g.no == lastNo then g // { versions = g.versions ++ [ v ]; } else g) acc.groups; };
  in
  (lib.foldl' fold { groups = []; key = null; } compatRows).groups;
in
# The table must account for exactly the releases under core/ (the
# swap fleet and the all-fleet both key off it).
let
  allGroupVersions = lib.concatMap (g: g.versions) groups;
in
assert lib.length allGroupVersions == lib.length (lib.unique allGroupVersions);
assert (lib.sort (lib.versionOlder) allGroupVersions) == (lib.sort (lib.versionOlder) versions);
# Versions ascend inside each group, so lib.last is the newest release
# (the group's anchor).
assert lib.all (g: (lib.sort (lib.versionOlder) g.versions) == g.versions) groups;
{
  inherit pkgsRoot pkgs lib eras coreDir versions eraPkg tierOf resOf;
  inherit fleetKeyDir fleetPubKey snapshotSpec groups;
  anchorOf = g: lib.last g.versions;
}
