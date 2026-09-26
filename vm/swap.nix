# Bitcoin Core archive swap fleet — one nixOS VM per datadir-compat
# group (see VM.md).
#
# Companion to vm/all.nix (one VM per version, each with its own
# datadir). The README "Data directory compatibility" table
# (tools/compat.tsv) partitions the releases into format groups: any
# two versions in the same group run on the *same* datadir. This fleet
# deploys one VM per group (groups 2..N; group 1 is 0.1.5, a
# source-only artifact with no binary) with every version of the group
# installed:
#
#   - the group's newest release (the anchor) runs at boot and does
#     the group's mainnet work;
#   - every other version has its own (disabled) systemd unit on the
#     same datadir; `deploy-swap.sh swap <group> <version>` stops the
#     active unit and starts the target — the same chain, different
#     binary;
#   - GUI-era members (0.2.x-0.4.x) run the single-process `bitcoin`
#     binary under a per-group Xvfb, so swapping works there too.
#
# Win vs vm/all.nix: one datadir per group instead of one per version —
# the 90 LevelDB releases share 12 chainstates instead of carrying 90
# copies. Cost: at most one version per group runs at a time.
#
# Model: same as vm/all.nix — NixOS 25.05 guest (eval-config.nix run
# wrapper, CoW qcow2 root), era nixpkgs checkouts from
# NIXPKGS_{16_09,20_09,23_11,25_05}, fleet ssh key from ../fleet-keys
# (FLEET_KEYS=/path/to/keydir overrides).
#
# Per-group resources follow the anchor's tier (vm/common.nix resOf).
# Ports (host 127.0.0.1, qemu user-net hostfwd per guest):
#   ssh 2222+idx, rpc 18443+idx — idx = group position 0..N-2 in
#   ascending group number (= ascending anchor version).
#
# Build on the build host:
#   nix-build vm/swap.nix -A swapBundle   # group images + the bundle
#   # single images (dotted attr names need -E, same as vm/all.nix):
#   nix-build $(nix-instantiate --eval -E '(import ./vm/swap.nix).images."16"')

let
  common = import ./common.nix;
  inherit (common) pkgsRoot pkgs lib eras eraPkg tierOf resOf;
  inherit (common) fleetKeyDir fleetPubKey snapshotSpec groups anchorOf;

  # Group 1 (0.1.5) has no binary — the fleet is groups 2..N.
  swapGroups = lib.filter (g: g.versions != [ "0.1.5" ]) groups;

  # Ascending group number == ascending anchor version; stable ports.
  idxOf = g: g.no - 2;
  hostOf = g: "btcg-${toString g.no}";
  verdash = v: lib.replaceStrings ["."] ["-"] v;
  unitName = host: v:
    if lib.versionOlder v "0.5.0" then "bitcoin-${host}-${verdash v}" # wx2.9 GUI
    else "bitcoind-${host}-${verdash v}";

  images = lib.mapAttrs (_: g:
    let
      host = hostOf g;
      anchor = anchorOf g;
      tier = tierOf anchor;
      res = resOf tier;
      idx = idxOf g;
      sshPort = 2222 + idx;
      rpcPort = 18443 + idx;
      datadir = "/var/lib/${host}";
      hasDaemon = lib.any (v: ! (lib.versionOlder v "0.5.0")) g.versions;
      hasGui = lib.any (v: lib.versionOlder v "0.5.0") g.versions;

      # Prune follows the anchor's tier (the regime of the shared
      # datadir); only binaries >= 0.11.0 know -prune.
      pruneFlag = tier:
        if tier == "archival" then [ ]
        else if tier == "archival-pruned" || tier == "ibd" then [ "-prune=550" ]
        else if lib.hasPrefix "snapshot" tier then [ "-prune=1100" ]
        else [ ];

      daemonFlags = v:
        [
          "-datadir=${datadir}"
          "-server"
          "-rpcbind=127.0.0.1"
          "-rpcport=${toString rpcPort}"
          "-rpcuser=archive"
          "-rpcpassword=archive"
        ]
        # -prune exists from 0.11.0; older GUI-era members get no prune.
        ++ (if lib.versionOlder v "0.11.0" then [ ] else pruneFlag tier)
        # -blocksxor exists from 28.0. A fresh datadir initialized by
        # a >= 28.0 member would otherwise store block *.dat files
        # XOR-obfuscated with a random key (blocksdir/xor.dat), which
        # pre-28.0 group members cannot read ("Corrupted block
        # database"). Force the plain (zero-key) form group-wide.
        ++ (if lib.versionOlder v "28.0" then [ ] else [ "-blocksxor=0" ]);

      vmCfg = import "${pkgsRoot}/nixos/lib/eval-config.nix" {
        system = builtins.currentSystem;
        # The guest's own nixpkgs generation (independent of NIX_PATH).
        modules = [
          # Not in the default NixOS module set in 25.05 (it sits in
          # documentation.nixos.extraModules) — NixOS VM tests and the
          # nix-builder-vm profile import it explicitly.
          (import "${pkgsRoot}/nixos/modules/virtualisation/qemu-vm.nix")
          ({ config, lib, pkgs, ... }: {
            # system.name follows networking.hostName -> unique per VM,
            # which also makes the run-script name unique.
            networking.hostName = host;
            services.openssh.enable = true;
            services.openssh.settings.PermitRootLogin = "prohibit-password";
            # The 25.05 era checkouts in this environment lack the
            # nixos users module, so inject the fleet key via /etc:
            services.openssh.settings.AuthorizedKeysFile =
              "/etc/ssh/authorized_keys";
            environment.etc."ssh/authorized_keys".text = fleetPubKey;
            virtualisation.cores = res.vcpu;
            system.stateVersion = "25.05";
            environment.systemPackages = lib.map eraPkg g.versions;
            virtualisation.memorySize = res.ramMib;
            virtualisation.diskSize = res.diskMib;
            virtualisation.forwardPorts =
              [ { proto = "tcp"; host.port = sshPort; guest.port = 22; } ]
              ++ lib.optional hasDaemon {
                proto = "tcp";
                host.port = rpcPort;
                guest.port = rpcPort;
              };
            systemd.services =
              (lib.optionalAttrs hasGui {
                "xvfb-${host}" = {
                  description = "Xvfb virtual display for the wx2.9 GUI binaries (swap fleet, group ${toString g.no})";
                  enable = true;
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig = {
                    ExecStart = "${pkgs.xorg.xvfb}/bin/Xvfb :99 -screen 0 1024x768x24";
                    Restart = "always";
                    RestartSec = 5;
                  };
                };
              })
              // lib.listToAttrs (lib.map (v: {
                name = unitName host v;
                value =
                  if lib.versionOlder v "0.5.0" then {
                    # Single-process GUI (node + UI), headless on Xvfb.
                    description = "Bitcoin Core ${v} GUI (swap fleet, group ${toString g.no})";
                    enable = v == anchor;
                    after = [ "xvfb-${host}.service" ];
                    wants = [ "xvfb-${host}.service" ];
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      Environment = [ "DISPLAY=:99" ];
                      ExecStart = "${pkgs.writeShellScriptBin "run-bitcoin-${verdash v}" ''
                        exec "${eraPkg v}/bin/bitcoin" -datadir=${datadir}
                      ''}/bin/run-bitcoin-${verdash v}";
                      Restart = "always";
                      RestartSec = 10;
                      StateDirectory = host;
                    };
                  }
                  else {
                    description = "Bitcoin Core ${v} (swap fleet, group ${toString g.no})";
                    enable = v == anchor;
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      ExecStart = "${eraPkg v}/bin/bitcoind ${lib.strings.concatStringsSep " " (daemonFlags v)}";
                      Restart = "always";
                      RestartSec = 10;
                      StateDirectory = host;
                    };
                  };
              }) g.versions);
          })
        ];
      };
    in
    vmCfg.config.system.build.vm
  ) (lib.listToAttrs (lib.map (g: { name = toString g.no; value = g; }) swapGroups));

  entries = lib.listToAttrs (lib.map (g: {
    name = toString g.no;
    value =
      {
        no = g.no;
        anchor = anchorOf g;
        versions = g.versions;
        engine = g.engine;
        tier = tierOf (anchorOf g);
        host = hostOf g;
        sshPort = 2222 + idxOf g;
        rpcPort =
          if lib.any (v: ! (lib.versionOlder v "0.5.0")) g.versions then 18443 + idxOf g
          else null;
        image = "${lib.attrByPath [ (toString g.no) ] {} images}";
        units = lib.listToAttrs (lib.map (v: {
          name = v;
          value = unitName (hostOf g) v;
        }) g.versions);
      }
      // lib.optionalAttrs (lib.hasPrefix "snapshot" (tierOf (anchorOf g))) {
        snapshotKey = lib.removePrefix "snapshot-" (tierOf (anchorOf g));
        inherit (snapshotSpec (lib.removePrefix "snapshot-" (tierOf (anchorOf g)))) file url bestBlock;
      };
  }) swapGroups);

  swapJson = pkgs.writeText "swap.json" (builtins.toJSON { groups = entries; });

  deployScript = pkgs.writeScript "deploy-swap.sh" ''
    #!/usr/bin/env bash
    # deploy-swap.sh — host-side deployment for the Bitcoin Core archive
    # swap fleet (one nixOS VM per datadir-compat group; see VM.md in
    # the repo).
    #
    #   deploy-swap.sh deploy             boot every group VM
    #   deploy-swap.sh swap <group> <version>
    #       switch the running version (same datadir)
    #   deploy-swap.sh anchor <group>     switch back to the group anchor
    #   deploy-swap.sh snapshot [group]   load UTXO snapshot(s) (snapshot-tier groups)
    #   deploy-swap.sh status             per-group anchor, running version, height
    #   deploy-swap.sh stop               stop every VM
    #
    # VM state lives under $BTC_FLEET_ROOT (default /var/lib/btc-fleet):
    # each VM's writable root disk is <root>/vm/btcg-<group>/vm.qcow2,
    # created on first boot by the NixOS run wrapper.
    set -euo pipefail

    FLEET_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT="''${BTC_FLEET_ROOT:-/var/lib/btc-fleet}"
    JSON="$FLEET_DIR/swap.json"
    SSH_KEY="$FLEET_DIR/keys/id_ed25519"

    die() { echo "SWAP-ERROR: $*" >&2; exit 1; }
    command -v jq >/dev/null || die "jq not found"
    [ -e "$JSON" ] || die "swap.json missing next to this script"
    [ -e "$SSH_KEY" ] || die "fleet ssh key missing next to this script"

    field() { jq -r --arg g "$1" ".groups[\$g].$2" "$JSON"; }
    group_list() { jq -r '.groups | keys[] | tonumber' "$JSON" | sort -n; }
    versions_of() { jq -r --arg g "$1" '.groups[\$g].versions[]' "$JSON"; }
    unit_of() { jq -r --arg g "$1" --arg v "$2" '.groups[\$g].units[\$v] // "none"' "$JSON"; }
    vm_dir() { echo "$ROOT/vm/btcg-$1"; }

    run_script() {
      local img
      img="$(field "$1" image)"
      ls "$img"/bin/run-*-vm 2>/dev/null | head -1
    }

    ssh_vm() {
      local g="$1"; shift
      ssh -F /dev/null -i "$SSH_KEY" -p "$(field "$g" sshPort)" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=15 root@127.0.0.1 "$@"
    }

    rpc() {
      local g="$1"; shift
      ssh_vm "$g" "bitcoin-cli -rpcport=$(field "$g" rpcPort) -rpcuser=archive -rpcpassword=archive $*"
    }

    running() { pgrep -f "$(vm_dir "$1")/vm.qcow2" >/dev/null 2>&1; }

    rpc_port_line() {
      local p
      p="$(field "$1" rpcPort)"
      [ "$p" = "null" ] || echo ", rpc 127.0.0.1:$p"
    }

    start_vm() {
      local g="$1" rs
      [ -e /dev/kvm ] || die "/dev/kvm missing — KVM not available"
      rs="$(run_script "$g")"
      [ -n "$rs" ] && [ -x "$rs" ] || die "run script missing for group $g"
      mkdir -p "$(vm_dir "$g")"
      if running "$g"; then
        echo "  group $g: already running"
        return 0
      fi
      NIX_DISK_IMAGE="$(vm_dir "$g")/vm.qcow2" "$rs" -display none -daemonize
      echo "  group $g: booted (ssh 127.0.0.1:$(field "$g" sshPort)$(rpc_port_line "$g"))"
    }

    wait_unit() {
      local g="$1" u="$2" i
      for i in $(seq 1 120); do
        ssh_vm "$g" "systemctl is-active $u" 2>/dev/null | grep -q '^active' && return 0
        sleep 5
      done
      die "unit $u of group $g not active after 10 minutes"
    }

    wait_rpc() {
      local g="$1" i
      for i in $(seq 1 120); do
        rpc "$g" getblockcount >/dev/null 2>&1 && return 0
        sleep 5
      done
      die "RPC of group $g not up after 10 minutes"
    }

    # Prints "<version>\t<unit>" for the active bitcoin unit of the
    # group, or nothing; always exits 0.
    active() {
      local g="$1" v u
      for v in $(versions_of "$g"); do
        u="$(unit_of "$g" "$v")"
        [ "$u" = "none" ] && continue
        if ssh_vm "$g" "systemctl is-active $u" 2>/dev/null | grep -q '^active'; then
          printf '%s\t%s\n' "$v" "$u"
          return 0
        fi
      done
      return 0
    }

    do_swap() {
      local g="$1" v="$2" cur_v cur_u target
      jq -e --arg g "$g" '.groups[$g]' "$JSON" >/dev/null || die "unknown group: $g"
      target="$(unit_of "$g" "$v")"
      [ "$target" != "none" ] || die "version $v is not a member of group $g"
      running "$g" || die "group $g VM is not running (deploy it first)"
      IFS=$'\t' read -r cur_v cur_u < <(active "$g") || true
      if [ -z "''${cur_v:-}" ]; then
        echo "  group $g: nothing active, starting $v ($target)"
        ssh_vm "$g" "systemctl start $target"
        wait_unit "$g" "$target"
      elif [ "$cur_v" = "$v" ]; then
        echo "  group $g: already at $v"
        return 0
      else
        echo "  group $g: stopping $cur_v ($cur_u), starting $v ($target)"
        ssh_vm "$g" "systemctl stop $cur_u && systemctl start $target"
        wait_unit "$g" "$target"
      fi
      if [ "$(field "$g" rpcPort)" != "null" ]; then
        wait_rpc "$g"
        echo "  group $g: now at $v (block $(rpc "$g" getblockcount))"
      else
        echo "  group $g: now at $v (GUI, no daemon RPC)"
      fi
    }

    load_snapshot() {
      local g="$1" host file url best host_snap bb
      host="$(field "$g" host)"
      file="$(field "$g" file)"
      url="$(field "$g" url)"
      best="$(field "$g" bestBlock)"
      host_snap="$ROOT/snap/$file"
      mkdir -p "$ROOT/snap"
      if [ ! -s "$host_snap" ]; then
        echo "  group $g: downloading $file (~9 GiB) ..."
        curl -fL --retry 3 -o "$host_snap" "$url"
      fi
      echo "  group $g: streaming $file into the guest ..."
      ssh_vm "$g" "mkdir -p /var/lib/$host"
      ssh_vm "$g" "cat > /var/lib/$host/$file" < "$host_snap"
      rpc "$g" loadtxoutset "$file"
      bb="$(rpc "$g" gettxoutsetinfo | jq -r .bestblock)"
      [ "$bb" = "$best" ] || die "group $g: snapshot bestblock mismatch: $bb != $best"
      ssh_vm "$g" "rm -f /var/lib/$host/$file"
      echo "  group $g: snapshot loaded (best block $bb)"
    }

    do_deploy() {
      local g
      for g in $(group_list); do
        echo "  group $g (anchor $(field "$g" anchor)): $(field "$g" tier)"
        start_vm "$g"
      done
      echo "Swap fleet deployed. Next: deploy-swap.sh snapshot (snapshot-tier groups) — status anytime."
    }

    do_snapshot() {
      local g
      if [ -n "''${1:-}" ]; then
        load_snapshot "$1"
      else
        for g in $(jq -r '.groups | to_entries[] | select(.value.snapshotKey != null) | .key' "$JSON"); do
          load_snapshot "$g"
        done
      fi
    }

    do_status() {
      local g h line cur_v
      for g in $(group_list); do
        printf 'group %-3s anchor %-7s %-16s ' "$g" "$(field "$g" anchor)" "$(field "$g" tier)"
        if running "$g"; then
          line="$(active "$g")"
          cur_v="''${line%%$'\t'*}"
          if [ -z "''${cur_v:-}" ]; then
            printf 'up (no bitcoin unit active)\n'
          elif [ "$(field "$g" rpcPort)" != "null" ]; then
            h="$(rpc "$g" getblockcount 2>/dev/null)" || h=""
            if [ -n "$h" ]; then
              printf 'running %-7s (block %s)\n' "$cur_v" "$h"
            else
              printf 'running %-7s (rpc not up yet)\n' "$cur_v"
            fi
          else
            printf 'running %-7s (gui, no rpc)\n' "$cur_v"
          fi
        else
          printf 'down\n'
        fi
      done
    }

    do_stop() {
      local g
      for g in $(group_list); do
        if running "$g"; then
          echo "  group $g: stopping"
          pkill -f "$(vm_dir "$g")/vm.qcow2" || true
        fi
      done
    }

    cmd="''${1:-status}"; shift || true
    case "$cmd" in
      deploy)   do_deploy ;;
      swap)     [ $# -eq 2 ] || die "swap needs <group> <version>"; do_swap "$1" "$2" ;;
      anchor)   [ $# -eq 1 ] || die "anchor needs <group>"; do_swap "$1" "$(field "$1" anchor)" ;;
      snapshot) do_snapshot "$@" ;;
      status)   do_status ;;
      stop)     do_stop ;;
      *) die "unknown command: $cmd (deploy | swap <group> <version> | anchor <group> | snapshot | status | stop)" ;;
    esac
  '';

  swapBundle = pkgs.stdenvNoCC.mkDerivation {
    name = "bitcoin-core-archive-swap-fleet";
    nativeBuildInputs = [ pkgs.jq ];
    # Plain files, not unpackable source archives — same pattern as
    # vm/all.nix (build-environment attrs, closure via buildInputs).
    dontUnpack = true;
    swapJson = swapJson;
    deployScript = deployScript;
    fleetKey = fleetKeyDir + "/id_ed25519";
    # Closure guarantee: the bundle only ships when every group image
    # built.
    buildInputs = lib.attrValues images;
    installPhase = ''
      # The deploy script resolves swap.json and keys/ relative to
      # itself (FLEET_DIR), so they live next to it in $out/bin.
      mkdir -p $out/bin/keys
      cp "$deployScript" $out/bin/deploy-swap.sh
      chmod +x $out/bin/deploy-swap.sh
      bash -n $out/bin/deploy-swap.sh
      cp "$swapJson" $out/bin/swap.json
      cp "$fleetKey" $out/bin/keys/id_ed25519
      chmod 600 $out/bin/keys/id_ed25519
      for img in ${lib.concatStringsSep " " (lib.map (i: "'${i}'") (lib.attrValues images))}; do
        ls "$img"/bin/run-*-vm >/dev/null 2>&1 || {
          echo "SWAP-BUILD-ERROR: no run-*-vm script in $img" >&2
          exit 1
        }
      done
      echo "swap fleet bundle ready: $(jq -r '.groups | length' $out/bin/swap.json) group VMs"
    '';
  };
in
{
  inherit images swapJson deployScript swapBundle;
  default = swapBundle;
}
