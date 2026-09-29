# Bitcoin Core archive fleet — one nixOS VM per version (see VM.md).
#
# Every release from v31.1 down to v0.1.5 gets its own VM. Each VM is a
# NixOS 25.05 system (its own nixpkgs generation) with the era
# derivation installed as a system package, so the era binary runs
# inside the 25.05 guest exactly like on the single test VM
# (tests/vm/).
#
# Model (direct boot, no prebuilt images):
#   - each VM is `config.system.build.vm` from the 25.05 checkout
#     (eval-config.nix): a run wrapper that creates a CoW qcow2 root
#     from its toplevel on first boot;
#   - era nixpkgs checkouts come from the environment:
#     NIXPKGS_{16_09,20_09,23_11,25_05} (absolute paths; the 25.05
#     checkout also defines the guest's nixpkgs generation);
# - the fleet ssh key lives in ../fleet-keys (<repo>/fleet-keys, git-ignored,
#     generated locally with ssh-keygen — fleet-only, disposable, never personal;
#     FLEET_KEYS=/path/to/keydir overrides the location).
#
# Per-VM resources (sparse qcow2 root, created on first boot):
#   disk: src/gui 2G | archival 40G | pruned/ibd 16G | snapshot 32G
#   ram:  src/gui 512M | archival/pruned 1G | ibd/snapshot 2G
#   vcpu: src/gui 1 | everything else 2
#
# Ports (host 127.0.0.1, qemu user-net hostfwd inside each guest):
#   ssh 2222+idx, rpc 18443+idx — idx = version index 0..136 in
#   descending version order.
#
# Build on the build host:
#   nix-build vm/all.nix -A fleet         # 137 toplevels + 137 wrappers
#   # -A cannot select dotted attr names, so single images go via -E:
#   nix-build $(nix-instantiate --eval -E '(import ./vm/all.nix).images."31.1"')

let
  # Shared era/version/tier/key helpers (vm/common.nix — also used by
  # vm/swap.nix and tests/vm/swap.nix).
  common = import ./common.nix;
  inherit (common) pkgsRoot pkgs lib eras versions eraPkg tierOf resOf;
  inherit (common) fleetKeyDir fleetPubKey snapshotSpec;

  # Descending version order defines the stable port index.
  versionsDesc = lib.reverseList versions;
  idxMap = lib.listToAttrs (lib.imap0 (i: v: { name = v; value = i; }) versionsDesc);
  idxOf = v: idxMap.${v};

  # Host name (and run-script/unit prefix) per version: dots -> dashes.
  hostOf = version: "btc-${lib.replaceStrings ["."] ["-"] version}";


  # Lazy per-attribute set: accessing one image evaluates only that
  # version's config (the fleet attr forces all of them via
  # buildInputs). genAttrs would make `nix-build -A images.31.1`
  # evaluate all 137 nixOS configs first (~25 min).
  images = lib.mapAttrs (version: _:
    let
      tier = tierOf version;
      host = hostOf version;
      res = resOf tier;
      idx = idxOf version;
      rpcPort = 18443 + idx;
      flags =
        if tier == "src" || tier == "gui" then null
        else
          [
            "-datadir=/var/lib/${host}"
            "-server"
            "-rpcbind=127.0.0.1"
            "-rpcport=${toString rpcPort}"
            # rpcuser MUST differ from rpcpassword: pre-0.10 Core aborts
            # at StartRPCThreads when the two are equal (or empty) on
            # networks where RequireRPCPassword() is true — mainnet.
            # regtest skips the check, which is why the VM tests pass
            # with equal credentials; the deployed mainnet fleet loops
            # on "you must set a rpcpassword in the configuration file".
            "-rpcuser=archive"
            "-rpcpassword=archivepass"
          ]
          ++ (
            if tier == "archival" then [ ]
            else if tier == "archival-pruned" || tier == "ibd" then [ "-prune=550" ]
            else [ "-prune=1100" ]
          );
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
            # This era checkout has no services/ssh/user-module.nix, so the
            # fleet key is injected via environment.etc -> a /nix/store
            # symlink. sshd's StrictModes walks the REAL path's ancestors
            # and refuses authorized keys under any group-writable
            # directory; a KVM host's /nix/store (virtfs-exported into the
            # guest) is routinely group-writable (multi-user nix: root:
            # nixbld 1775), which made every fleet ssh login fail with
            # "bad ownership or modes for directory /nix/store". The key
            # content is store-immutable, so relax StrictModes instead of
            # requiring pristine store perms on every deploy target.
            services.openssh.settings.StrictModes = false;
            services.openssh.settings.AuthorizedKeysFile =
              "/etc/ssh/authorized_keys";
            environment.etc."ssh/authorized_keys".text = fleetPubKey;
            virtualisation.cores = res.vcpu;
            system.stateVersion = "25.05";
            environment.systemPackages = [ (eraPkg version) ];
            virtualisation.memorySize = res.ramMib;
            virtualisation.diskSize = res.diskMib;
            virtualisation.forwardPorts =
              [ { proto = "tcp"; host.port = 2222 + idx; guest.port = 22; } ]
              ++ lib.optional (flags != null) {
                proto = "tcp";
                host.port = rpcPort;
                guest.port = rpcPort;
              };
            systemd.services = lib.optionalAttrs (flags != null) {
              "bitcoind-${host}" = {
                description = "Bitcoin Core ${version} (archive fleet)";
                enable = true;
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  ExecStart = "${eraPkg version}/bin/bitcoind ${lib.strings.concatStringsSep " " flags}";
                  Restart = "always";
                  RestartSec = 10;
                  StateDirectory = host;
                };
              };
            };
          })
        ];
      };
    in
    vmCfg.config.system.build.vm
  ) (lib.listToAttrs (lib.map (v: { name = v; value = true; }) versions));


  entries = lib.listToAttrs (lib.map (v: {
    name = v;
    value =
      {
        tier = tierOf v;
        sshPort = 2222 + idxOf v;
        rpcPort = 18443 + idxOf v;
        image = "${images.${v}}";
      }
      // lib.optionalAttrs (lib.hasPrefix "snapshot" (tierOf v)) {
        snapshotKey = lib.removePrefix "snapshot-" (tierOf v);
        inherit (snapshotSpec (lib.removePrefix "snapshot-" (tierOf v))) file url bestBlock;
      };
  }) versions);

  fleetJson = pkgs.writeText "fleet.json" (builtins.toJSON {
    versions = entries;
  });

  deployScript = pkgs.writeScript "deploy-fleet.sh" ''
    #!/usr/bin/env bash
    # deploy-fleet.sh — host-side deployment for the Bitcoin Core archive
    # fleet (one nixOS VM per version; see VM.md in the repo).
    #
    #   deploy-fleet.sh deploy [--wave N]   boot every VM (N at a time)
    #   deploy-fleet.sh snapshot [version]  load UTXO snapshot(s)
    #   deploy-fleet.sh status              per-version tier + block height
    #   deploy-fleet.sh stop                stop every VM
    #
    # VM state lives under $BTC_FLEET_ROOT (default /var/lib/btc-fleet):
    # each VM's writable root disk is <root>/vm/<version>/vm.qcow2,
    # created on first boot by the NixOS run wrapper.
    set -euo pipefail

    FLEET_DIR="$(cd "$(dirname "$0")" && pwd)"
    ROOT="''${BTC_FLEET_ROOT:-/var/lib/btc-fleet}"
    JSON="$FLEET_DIR/fleet.json"
    SSH_KEY="$FLEET_DIR/keys/id_ed25519"

    die() { echo "FLEET-ERROR: $*" >&2; exit 1; }
    command -v jq >/dev/null || die "jq not found"
    [ -e "$JSON" ] || die "fleet.json missing next to this script"
    [ -e "$SSH_KEY" ] || die "fleet ssh key missing next to this script"

    field() { jq -r --arg v "$1" ".versions[\$v].$2" "$JSON"; }
    version_list() { jq -r '.versions | keys[]' "$JSON"; }
    vm_dir() { echo "$ROOT/vm/$1"; }
    host_name() { echo "btc-$(echo "$1" | tr '.' '-')"; }

    run_script() {
      local img
      img="$(field "$1" image)"
      ls "$img"/bin/run-*-vm 2>/dev/null | head -1
    }

    ssh_vm() {
      local v="$1"; shift
      ssh -F /dev/null -i "$SSH_KEY" -p "$(field "$v" sshPort)" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=15 root@127.0.0.1 "$@"
    }

    rpc() {
      local v="$1"; shift
      ssh_vm "$v" "bitcoin-cli -rpcport=$(field "$v" rpcPort) -rpcuser=archive -rpcpassword=archivepass $*"
    }

    running() { pgrep -f "$(vm_dir "$1")/vm.qcow2" >/dev/null 2>&1; }

    start_vm() {
      local v="$1" rs
      [ -e /dev/kvm ] || die "/dev/kvm missing — KVM not available"
      rs="$(run_script "$v")"
      [ -n "$rs" ] && [ -x "$rs" ] || die "run script missing for $v"
      mkdir -p "$(vm_dir "$v")"
      if running "$v"; then
        echo "  $v: already running"
        return 0
      fi
      NIX_DISK_IMAGE="$(vm_dir "$v")/vm.qcow2" "$rs" -display none -daemonize
      echo "  $v: booted (ssh 127.0.0.1:$(field "$v" sshPort), rpc 127.0.0.1:$(field "$v" rpcPort))"
    }

    wait_rpc() {
      local v="$1" i
      for i in $(seq 1 120); do
        rpc "$v" getblockcount >/dev/null 2>&1 && return 0
        sleep 5
      done
      die "RPC of $v not up after 10 minutes"
    }

    load_snapshot() {
      local v="$1" host key file url best host_snap bb
      host="$(host_name "$v")"
      key="$(field "$v" snapshotKey)"
      file="$(field "$v" file)"
      url="$(field "$v" url)"
      best="$(field "$v" bestBlock)"
      host_snap="$ROOT/snap/$file"
      mkdir -p "$ROOT/snap"
      if [ ! -s "$host_snap" ]; then
        echo "  $v: downloading $file (~9 GiB) ..."
        curl -fL --retry 3 -o "$host_snap" "$url"
      fi
      echo "  $v: streaming $file into the guest ..."
      ssh_vm "$v" "mkdir -p /var/lib/$host"
      ssh_vm "$v" "cat > /var/lib/$host/$file" < "$host_snap"
      ssh_vm "$v" "bitcoin-cli -rpcport=$(field "$v" rpcPort) -rpcuser=archive -rpcpassword=archivepass loadtxoutset $file"
      bb="$(ssh_vm "$v" "bitcoin-cli -rpcport=$(field "$v" rpcPort) -rpcuser=archive -rpcpassword=archivepass gettxoutsetinfo | jq -r .bestblock")"
      [ "$bb" = "$best" ] || die "$v: snapshot bestblock mismatch: $bb != $best"
      ssh_vm "$v" "rm -f /var/lib/$host/$file"
      echo "  $v: snapshot $key loaded (best block $bb)"
    }

    do_deploy() {
      local wave=16 v n
      while [ "''${1:-}" = "--wave" ]; do
        wave="$2"; shift 2
      done
      n=0
      for v in $(version_list); do
        if [ "$n" -ge "$wave" ]; then
          wait -n 2>/dev/null || true
          n=$((n - 1))
        fi
        echo "  $v: $(field "$v" tier)"
        start_vm "$v" &
        n=$((n + 1))
      done
      wait
      echo "Fleet deployed. Next: deploy-fleet.sh snapshot (snapshot tier) — status anytime."
    }

    do_snapshot() {
      local v
      if [ -n "''${1:-}" ]; then
        load_snapshot "$1"
      else
        for v in $(jq -r '.versions | to_entries[] | select(.value.snapshotKey != null) | .key' "$JSON"); do
          load_snapshot "$v"
        done
      fi
    }

    do_status() {
      local v h
      for v in $(version_list); do
        printf '%-10s %-16s ' "$v" "$(field "$v" tier)"
        if running "$v"; then
          case "$(field "$v" tier)" in
            src|gui) printf 'up (no daemon)\n' ;;
            *)
              h="$(rpc "$v" getblockcount 2>/dev/null)" || h=""
              if [ -n "$h" ]; then
                printf 'up (block %s)\n' "$h"
              else
                printf 'up (rpc not up yet)\n'
              fi
              ;;
          esac
        else
          printf 'down\n'
        fi
      done
    }

    do_stop() {
      local v
      for v in $(version_list); do
        if running "$v"; then
          echo "  $v: stopping"
          pkill -f "$(vm_dir "$v")/vm.qcow2" || true
        fi
      done
    }

    cmd="''${1:-status}"; shift || true
    case "$cmd" in
      deploy)   do_deploy "$@" ;;
      snapshot) do_snapshot "$@" ;;
      status)   do_status ;;
      stop)     do_stop ;;
      *) die "unknown command: $cmd (deploy | snapshot | status | stop)" ;;
    esac
  '';

  fleet = pkgs.stdenvNoCC.mkDerivation {
    name = "bitcoin-core-archive-fleet";
    nativeBuildInputs = [ pkgs.jq ];
    # Plain files, not unpackable source archives — they must NOT go
    # in srcs (stdenv would try to unpack them). As derivation
    # attributes they become build-environment variables holding
    # their store paths, and the interpolation in installPhase keeps
    # them in the closure.
    # No source at all: the bundle is assembled from buildInputs and
    # the file attributes above, so skip unpackPhase (stdenv
    # otherwise dies with "$src or $srcs should point to the source").
    dontUnpack = true;
    fleetJson = fleetJson;
    deployScript = deployScript;
    fleetKey = fleetKeyDir + "/id_ed25519";
    # Closure guarantee: the bundle only ships when every VM image built.
    buildInputs = lib.attrValues images;
    installPhase = ''
      # The deploy script resolves fleet.json and keys/ relative to
      # itself (FLEET_DIR), so they live next to it in $out/bin.
      mkdir -p $out/bin/keys
      cp "$deployScript" $out/bin/deploy-fleet.sh
      chmod +x $out/bin/deploy-fleet.sh
      bash -n $out/bin/deploy-fleet.sh
      cp "$fleetJson" $out/bin/fleet.json
      cp "$fleetKey" $out/bin/keys/id_ed25519
      chmod 600 $out/bin/keys/id_ed25519
      for img in ${lib.concatStringsSep " " (lib.map (i: "'${i}'") (lib.attrValues images))}; do
        ls "$img"/bin/run-*-vm >/dev/null 2>&1 || {
          echo "FLEET-BUILD-ERROR: no run-*-vm script in $img" >&2
          exit 1
        }
      done
      echo "fleet bundle ready: $(jq -r '.versions | length' $out/bin/fleet.json) VMs"
    '';
  };
in
{
  inherit images fleet;
  default = fleet;
}
