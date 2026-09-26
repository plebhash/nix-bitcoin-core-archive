#!/usr/bin/env bash
# Build (and run) the nixOS VM test for the swap fleet (vm/swap.nix).
#
# Companion to run-vm-test.sh (tests/vm/default.nix, all 137 versions
# one-VM-per-version). This test boots ONE nixOS 25.05 machine and
# runs two check layers in it:
#   1. static contract checks on the swap fleet's generated surface
#      (swap.json + deploy-swap.sh),
#   2. real regtest datadir swaps on four (anchor -> older) pairs,
#      one per format era — the newer member's chainstate must be
#      read by the older member of its compat group.
#
# The era nixpkgs checkouts are needed to evaluate the pair members
# with their era's generation (same mechanism as run-vm-test.sh);
# the test VM itself is NIXPKGS_25_05.
#
# Usage: tests/vm/run-swap-test.sh
set -euo pipefail
export PATH=/nix/var/nix/profiles/default/bin:$PATH
cd "$(dirname "$0")/../.."

# The era nixpkgs checkouts (absolute paths to source trees) are
# passed in by environment variable:
#   NIXPKGS_16_09, NIXPKGS_20_09, NIXPKGS_23_11, NIXPKGS_25_05
# NIXPKGS_25_05 also provides the VM's own nixpkgs generation.
: "${NIXPKGS_16_09:?set NIXPKGS_16_09 to the absolute path of that era's nixpkgs checkout}"
: "${NIXPKGS_20_09:?set NIXPKGS_20_09 to the absolute path of that era's nixpkgs checkout}"
: "${NIXPKGS_23_11:?set NIXPKGS_23_11 to the absolute path of that era's nixpkgs checkout}"
: "${NIXPKGS_25_05:?set NIXPKGS_25_05 to the absolute path of that era's nixpkgs checkout}"
export NIXPKGS_16_09 NIXPKGS_20_09 NIXPKGS_23_11 NIXPKGS_25_05
export NIX_PATH=nixpkgs="$NIXPKGS_25_05"

# Build + run the VM test. The test passes when every static check
# and all four swaps succeed inside the booted nixOS machine (the
# driver fails the build on any FAIL line in the runner output).
nix-build tests/vm/swap.nix
echo "SWAP VM TEST PASSED"
