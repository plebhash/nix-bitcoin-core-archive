#!/usr/bin/env bash
# Build (and run) the nixOS VM test for the whole archive.
#
# tests/vm/default.nix imports every core/<version>/default.nix with the
# nixpkgs generation of its era (absolute paths into the build host's
# nixpkgs checkouts — run this on the build host), so already-built
# outputs are cache hits and the VM image only pulls them into its
# closure. The VM itself is built from the NEWEST nixpkgs generation:
# its glibc must be able to run binaries from every era (newer glibc
# runs older binaries, not the other way around).
#
# Usage: tests/vm/run-vm-test.sh
set -euo pipefail
export PATH=/nix/var/nix/profiles/default/bin:$PATH
cd "$(dirname "$0")/../.."

# The era nixpkgs checkouts (absolute paths to source trees) are
# passed in by environment variable, e.g.:
#   NIXPKGS_16_09=/path/to/nixpkgs-16.09  NIXPKGS_20_09=/path/to/nixpkgs-20.09
#   NIXPKGS_23_11=/path/to/nixpkgs-23.11  NIXPKGS_25_05=/path/to/nixpkgs-25.05
# NIXPKGS_25_05 also provides the VM's own nixpkgs generation.
: "${NIXPKGS_16_09:?set NIXPKGS_16_09 to the absolute path of that era's nixpkgs checkout}"
: "${NIXPKGS_20_09:?set NIXPKGS_20_09 to the absolute path of that era's nixpkgs checkout}"
: "${NIXPKGS_23_11:?set NIXPKGS_23_11 to the absolute path of that era's nixpkgs checkout}"
: "${NIXPKGS_25_05:?set NIXPKGS_25_05 to the absolute path of that era's nixpkgs checkout}"
export NIXPKGS_16_09 NIXPKGS_20_09 NIXPKGS_23_11 NIXPKGS_25_05
export NIX_PATH=nixpkgs="$NIXPKGS_25_05"

# Informational pre-check: which versions have no matching store path
# yet? Drifted derivations are rebuilt once by nix-build (cached after);
# a missing store path is therefore not fatal, just reported.
missing=()
for d in core/*/; do
  v=$(basename "$d")
  [ "$v" = "_deps" ] && continue
  store=""
  for p in /nix/store/*-"bitcoind-$v" /nix/store/*-"bitcoin-src-$v"; do
    [ -d "$p" ] && { store="$p"; break; }
  done
  [ -z "$store" ] && missing+=("$v")
done
echo "store pre-check: $(ls -d core/*/ | wc -l) version dirs, missing: ${#missing[@]}"
[ ${#missing[@]} -eq 0 ] || { echo "  missing: ${missing[*]}"; echo "  (these will be built during the VM build)"; }

# Build + run the VM test. The test passes when every check in the
# runner script succeeds inside the booted nixOS machine (the driver
# fails the build on any FAIL line in the runner output).
nix-build tests/vm
echo "VM TEST PASSED"
