# nixOS VM test for the swap fleet (vm/swap.nix) — companion to
# tests/vm/default.nix (vm/all.nix, one VM per version).
#
# Two layers, matching what the harness can do on the test machine
# (a nixOS VM with no nested KVM — same constraint the all-VM
# harness works under):
#
#   1. Static contract checks on the swap fleet's generated surface
#      (swap.json + deploy-swap.sh): group count, anchor == newest
#      version, sshPort arithmetic, rpcPort null exactly for the
#      GUI-only groups, bitcoind-/bitcoin- unit naming, snapshot
#      fields exactly for snapshot-tier anchors, image store paths,
#      deploy-script syntax, and a `status` smoke run.
#   2. Real regtest datadir swaps on four representative
#      (anchor -> older) pairs, one per format era: the anchor (the
#      group's newest release) initializes a regtest datadir and
#      mines 50 blocks; it stops; the wallet files are removed (the
#      compatibility claim under test is chainstate, and wallet
#      formats are not intra-group compatible everywhere — see
#      VM.md); the older member starts on the same datadir and must
#      read all 50 blocks via RPC. This is the binary-level
#      guarantee behind the fleet's `swap` command and the README's
#      data-directory compatibility table.
#
# The 15 swap images themselves are a host-side build
# (`nix-build vm/swap.nix -A swapBundle`); booting one is a KVM
# operation, which this harness does not nest.
#
# Run on the build host (era NIXPKGS_* checkouts as absolute paths,
# see run-swap-test.sh):
#   NIX_PATH=nixpkgs=$NIXPKGS_25_05 nix-build tests/vm/swap.nix

{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } }:

let
  lib = pkgs.lib;
  common = import ../../vm/common.nix;
  inherit (common) eraPkg groups anchorOf;
  swapFleet = import ../../vm/swap.nix;

  # Swap pairs: (anchor, older) — both members of the same compat
  # group, anchor = the group's newest release. One per format era:
  #   0.9.5  -> 0.9.0   LevelDB era, setgenerate on-demand mining
  #   0.11.3 -> 0.10.0  synchronous generate RPC, pre-obfuscation coin values
  #   22.1   -> 0.20.0  spans nixpkgs eras (23.11 -> 20.09)
  #   31.1   -> 26.0    modern era, widest group
  pairOf = anchor: older:
    let
      g = lib.findFirst (gs: builtins.elem anchor gs.versions
        && builtins.elem older gs.versions) null groups;
    in
    assert g != null
      && anchorOf g == anchor
      && builtins.elem older g.versions
      && older != anchor;
    { inherit anchor older; group = g.no; };
  pairs = [
    (pairOf "0.9.5" "0.9.0")
    (pairOf "0.11.3" "0.10.0")
    (pairOf "22.1" "0.20.0")
    (pairOf "31.1" "26.0")
  ];
  # Per-era mining RPC for the anchor (verified against the binaries):
  #   setgen       < 0.11.0:  setgenerate [true, 50], one on-demand burst
  #   gen          0.11.x:    synchronous generate [50]
  #   wallet-auto  0.13.0-0.17.x: default wallet auto-creates, generatetoaddress
  #   wallet-create >= 0.18:  createwallet, wallet RPCs via /wallet/<name> URI
  mineMode = v:
    if lib.versionOlder v "0.11.0" then "setgen"
    else if lib.versionOlder v "0.13.0" then "gen"
    else if lib.versionOlder v "0.18.0" then "wallet-auto"
    else "wallet-create";
  swapVersions = lib.unique (lib.flatten (lib.map (p: [ p.anchor p.older ]) pairs));
  expectGroups = builtins.length groups - 1; # group 1 (0.1.5) is source-only
  expectOk = 5 + builtins.length pairs;     # static checks + swaps

  runner = pkgs.writeScript "swap-runner" ''
    set -u
    fail=0
    S=/etc/btc-swap
    RPCU=archive
    RPCP=swap-test-pass
    RPCPORT=18443

    rpc() { # timeoutSec method paramsJson [walletPath]
      curl -s -m "$1" -u "$RPCU:$RPCP" "http://127.0.0.1:$RPCPORT/''${4:-}" \
        -d "{\"method\":\"$2\",\"params\":$3}" 2>/dev/null
    }
    count() { rpc 5 getblockcount "[]" | jq -r 'select(.result != null) | .result' 2>/dev/null; }

    wait_rpc() {
      local i=0 c
      while [ $i -lt 120 ]; do
        sleep 1
        c=$(count)
        [ -n "$c" ] && return 0
        i=$((i+1))
      done
      return 1
    }

    stop_daemon() { # datadir
      # RPC stop (the CLI -stop option was removed in 0.21, and a
      # hard kill skips the shutdown flush — chainstate must be on
      # disk before the older member starts on the same datadir).
      rpc 30 stop '[]' >/dev/null 2>&1 || true
      local i=0
      while [ $i -lt 25 ]; do
        pgrep -f "datadir=$1" >/dev/null 2>&1 || return 0
        sleep 1
        i=$((i+1))
      done
      pkill -9 -f "datadir=$1" 2>/dev/null || true
      sleep 1
    }

    startup_log() { # datadir — daemon log tail, both pre-0.13 (datadir
      # root) and 0.13+ (datadir/regtest/) layouts.
      cat "$1/debug.log" "$1/regtest/debug.log" 2>/dev/null | tail -5
    }

    # --- static checks on the swap fleet's generated surface ---
    jq -e "(.groups | length) == ${toString expectGroups}" "$S/swap.json" >/dev/null \
      && echo "OK static: group count" \
      || { echo "FAIL static: group count (want ${toString expectGroups})"; fail=1; }

    # anchor == newest version; sshPort = 2222 + no - 2; rpcPort null
    # exactly when every member is a GUI-era binary; image is a store
    # path; snapshotKey present exactly for snapshot-tier anchors.
    jq -e '
      def isgui: split(".") as $p
        | ($p[0] | tonumber) == 0 and (($p[1] | tonumber) < 5);
      [ .groups[] as $g
        | select(
            ($g.anchor != ($g.versions | last))
            or ($g.sshPort != (2222 + ($g.no - 2)))
            or ((($g.rpcPort == null) and (([$g.versions[] | isgui] | all) | not))
                or ((($g.rpcPort == null) | not) and ([$g.versions[] | isgui] | all)))
            or (($g.image | startswith("/nix/store/")) | not)
        or (($g.snapshotKey == null) == ($g.tier | startswith("snapshot")))
          ) ] | length == 0' "$S/swap.json" >/dev/null \
      && echo "OK static: per-group invariants" \
      || { echo "FAIL static: per-group invariants"; fail=1; }

    # unit naming: the GUI era (0.2.x-0.4.x) ships one binary named
    # bitcoin, every daemon-era version ships bitcoind.
    jq -e '
      def isgui: split(".") as $p
        | ($p[0] | tonumber) == 0 and (($p[1] | tonumber) < 5);
        [ .groups[].units | to_entries[]
        | select(
          ((.key | isgui) and (.value | startswith("bitcoin-") | not))
          or (((.key | isgui) | not) and (.value | startswith("bitcoind-") | not))
          ) ] | length == 0' "$S/swap.json" >/dev/null \
      && echo "OK static: unit naming" \
      || { echo "FAIL static: unit naming"; fail=1; }

    if bash -n "$S/deploy-swap.sh" 2>/dev/null; then
      echo "OK static: deploy script syntax"
    else
      echo "FAIL static: deploy script syntax"
      fail=1
    fi

    # `status` must run clean with zero VMs booted (all lines "down").
    if out=$(bash "$S/deploy-swap.sh" status 2>&1); then
      echo "$out"
      if echo "$out" | grep -q ' down'; then
        echo "OK static: deploy status smoke"
      else
        echo "FAIL static: deploy status output"
        fail=1
      fi
    else
      echo "FAIL static: deploy status smoke"
      printf '%s\n' "$out" | head -5
      fail=1
    fi

    # --- real regtest swaps ---
    # The anchor (group's newest release) initializes a regtest
    # datadir, mines 50 blocks, stops. Wallet files are removed —
    # the claim under test is chainstate compatibility, and wallet
    # formats are not intra-group compatible in every pair. The
    # older member starts on the same datadir and must read all 50
    # blocks via RPC.
    swap_case() { # group anchor older anchorBin olderBin mineMode olderDisableWallet
      gno=$1; anchor=$2; older=$3; A=$4; O=$5; MINEMODE=$6; ODW=$7
      d=$(mktemp -d /tmp/btcswap-XXXXXX)
      if ! "$A" -regtest -daemon -server -rpcuser=$RPCU -rpcpassword=$RPCP \
          -rpcport=$RPCPORT -port=$((RPCPORT+1)) -rpcbind=127.0.0.1 -datadir="$d" \
          > "$d.anchor.out" 2>&1; then
        echo "FAIL swap G$gno: anchor $anchor failed to start: $(head -1 "$d.anchor.out")"
        fail=1
        rm -rf "$d"
        return
      fi
      # -daemon forks and the parent exits 0 even when the child dies
      # at startup (port bind, unknown flag); verify liveness before
      # the 120 s RPC wait.
      sleep 3
      if ! pgrep -f "datadir=$d" >/dev/null 2>&1; then
        echo "FAIL swap G$gno: anchor $anchor died at startup: $(startup_log "$d")"
        fail=1
        rm -rf "$d"
        return
      fi
      if ! wait_rpc; then
        echo "FAIL swap G$gno: anchor $anchor started but no RPC: $(startup_log "$d")"
        stop_daemon "$d"
        fail=1
        rm -rf "$d"
        return
      fi
      # Mining, era-aware (verified against each era's binary):
      #   setgen (< 0.11.0): no generate RPC; one on-demand
      #     setgenerate burst mines the full 50.
      #   gen (0.11.x-0.12.x): synchronous generate RPC.
      #   wallet-auto (0.13.0-0.17.x): the default wallet
      #     auto-creates; mine via generatetoaddress.
      #   wallet-create (>= 0.18): no auto wallet; createwallet
      #     first, wallet RPCs on the /wallet/<name> URI.
      mout=""
      c=""
      case "$MINEMODE" in
      setgen)
        mout=$(rpc 300 setgenerate '[true, 50]')
        c=$(count)
        ;;
      gen)
        mout=$(rpc 300 generate '[50]')
        c=$(count)
        ;;
      wallet-auto)
        a=$(rpc 10 getnewaddress '[]' | jq -r 'select(.result != null) | .result' 2>/dev/null)
        mout=$(rpc 300 generatetoaddress "[50, \"$a\"]")
        c=$(count)
        ;;
      wallet-create)
        mout=$(rpc 30 createwallet '["swapw"]')
        a=$(rpc 10 getnewaddress '[]' wallet/swapw | jq -r 'select(.result != null) | .result' 2>/dev/null)
        mout=$(rpc 300 generatetoaddress "[50, \"$a\"]" wallet/swapw)
        c=$(count)
        ;;
      esac
      if [ -z "$c" ] || [ "$c" -lt 50 ] 2>/dev/null; then
        echo "FAIL swap G$gno: anchor $anchor mined to ''${c:-0}, want >= 50 (rpc: $mout)"
        stop_daemon "$d"
        fail=1
        rm -rf "$d"
        return
      fi
      stop_daemon "$d"
      rm -f "$d/wallet.dat" "$d/regtest/wallet.dat" "$d/regtest/wallet" "$d/regtest/labels.conf"
      rm -rf "$d/regtest/wallets"
      oxtra=""
      if [ "$ODW" = "1" ]; then oxtra="-disablewallet"; fi
      if ! "$O" -regtest -daemon -server -rpcuser=$RPCU -rpcpassword=$RPCP \
          -rpcport=$RPCPORT -port=$((RPCPORT+1)) -rpcbind=127.0.0.1 -datadir="$d" $oxtra \
          > "$d.older.out" 2>&1; then
        echo "FAIL swap G$gno: older $older failed to start on $anchor's datadir: $(head -1 "$d.older.out")"
        fail=1
        rm -rf "$d"
        return
      fi
      sleep 3
      if ! pgrep -f "datadir=$d" >/dev/null 2>&1; then
        echo "FAIL swap G$gno: older $older died at startup: $(startup_log "$d")"
        fail=1
        rm -rf "$d"
        return
      fi
      if ! wait_rpc; then
        echo "FAIL swap G$gno: older $older started but no RPC: $(startup_log "$d")"
        pkill -9 -f "datadir=$d" 2>/dev/null || true
        fail=1
        rm -rf "$d"
        return
      fi
      c=$(count)
      if [ -z "$c" ] || [ "$c" -lt 50 ] 2>/dev/null; then
        echo "FAIL swap G$gno: older $older read count ''${c:-0} from $anchor's datadir, want >= 50"
        stop_daemon "$d"
        fail=1
        rm -rf "$d"
        return
      fi
      echo "OK swap: G$gno $anchor -> $older ($c blocks read)"
      stop_daemon "$d"
      rm -rf "$d"
    }

    ${lib.concatStringsSep "\n" (lib.map (p:
      ''
    swap_case ${toString p.group} ${p.anchor} ${p.older} \
      ${eraPkg p.anchor}/bin/bitcoind ${eraPkg p.older}/bin/bitcoind \
      ${mineMode p.anchor} \
      ${if lib.versionOlder p.older "0.15.0" then "0" else "1"}
      ''
    ) pairs)}

    echo "=== swap runner done ==="
    exit $fail
  '';

  # writeScript yields a bare file, but environment.systemPackages
  # needs a directory, so wrap the runner in a package layout (same
  # as tests/vm/default.nix).
  runnerPkg = pkgs.runCommand "swap-runner-pkg" {} ''
    mkdir -p $out/bin
    cp ${runner.outPath} $out/bin/swap-runner
    chmod +x $out/bin/swap-runner
    bash -n $out/bin/swap-runner
  '';

  testSet = (import (pkgs.path + "/nixos/tests/make-test-python.nix")) ({
    name = "nix-bitcoin-core-archive-swap";
    skipLint = true;

    nodes.machine = {
      # The pair members, each with the nixpkgs generation of its
      # era (already-built outputs are cache hits — same mechanism
      # as tests/vm/default.nix).
      environment.systemPackages =
        (builtins.map eraPkg swapVersions)
        ++ [
          runnerPkg
          pkgs.curl
          pkgs.jq
          pkgs.psmisc
        ];
      # The swap fleet's generated surface (same evaluation the
      # bundle installs on a host): runner working directory, deploy
      # script, and a placeholder key (the status smoke never uses
      # it, but deploy-swap.sh guards against a missing key before
      # it ever touches ssh).
      environment.etc."btc-swap/swap.json".source = swapFleet.swapJson;
      environment.etc."btc-swap/deploy-swap.sh".source =
        swapFleet.deployScript;
      environment.etc."btc-swap/keys/id_ed25519".text =
        "test-only placeholder key (never used by the status smoke)\n";
    };

    # Four daemon start/stop cycles per pair plus mining: well under
    # an hour, even with slow era-daemon startups.
    globalTimeout = 3600;

    testScript = ''
      start_all()
      # Redirect before exec so the backgrounded process holds no
      # write end of the driver's output pipe (see the long comment
      # in tests/vm/default.nix: with tee, the launch command
      # "finished" exactly when the runner did).
      machine.succeed("nohup ${runnerPkg.outPath}/bin/swap-runner > /tmp/swap.out 2>&1 &")
      while True:
          status, tail = machine.execute(
              "sleep 60; "
              "tail -n 25 /tmp/swap.out; "
              "pgrep -f 'swap-[r]unner' >/dev/null && exit 1 || exit 0",
              timeout=300,
          )
          machine.log("PROGRESS: " + tail.rstrip())
          if status == 0:
              break
      machine.succeed(
          "out=$(grep -E '^FAIL' /tmp/swap.out || true); "
          "if [ -n \"$out\" ]; then printf '%s\\n' \"$out\"; exit 1; fi"
      )
      machine.succeed(
          "ok=$(grep -c '^OK' /tmp/swap.out || true); "
          "fl=$(grep -c '^FAIL' /tmp/swap.out || true); "
          "echo SUMMARY: ok=$ok fail=$fl; "
          "last=$(tail -n 1 /tmp/swap.out); "
          "if [ \"$fl\" -gt 0 ] || [ \"$ok\" -lt ${toString expectOk} ] || [ \"$last\" != \"=== swap runner done ===\" ]; then exit 1; fi"
      )
      machine.shutdown()
    '';
  });
in
testSet {
  system = pkgs.system;
  pkgs = pkgs;
}
