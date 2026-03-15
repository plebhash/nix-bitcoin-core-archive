{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
, cmake ? pkgs.cmake
, pkg-config ? pkgs.pkg-config
, util-linux ? pkgs.util-linux
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? pkgs.miniupnpc
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, sqlite ? pkgs.sqlite
, capnproto ? pkgs.capnproto
, python3 ? pkgs.python3
, coreRelease ? "30.0"
, fibreTag ? null
, tag ? null
, rev ? null
, hash ? null
}:

let
  mkCoreLikeFork = import ../lib/mk-core-like-fork.nix {
    inherit
      lib
      stdenv
      fetchFromGitHub
      cmake
      pkg-config
      util-linux
      boost
      libevent
      miniupnpc
      zeromq
      zlib
      sqlite
      capnproto
      python3
      ;
  };

  effectiveTag = if fibreTag != null then fibreTag else tag;

  # Add new Core release mappings (e.g. 30.1, 30.2) here.
  releaseMetadata = {
    "30.0" = {
      tag = "v30.0-fibre";
      rev = "8904bbdc46c052ccee587faa44b166974dedf839";
      # v30.0-fibre source hash
      hash = "sha256-aitFf2jWzJJ+Viqv/zxx0jj25Wn2BRb7L2LMfH6WafE=";
    };
  };
in
mkCoreLikeFork {
  pname = "bitcoind-bitcoinfibre";
  description = "Bitcoin FIBRE fork with modular Core release metadata";
  owner = "bitcoinfibre";
  repo = "bitcoinfibre";

  inherit coreRelease releaseMetadata rev hash;
  tag = effectiveTag;

  extraBuildInputs = [ capnproto ];

  doCheck = false;

  extraMeta = {
    homepage = "https://github.com/bitcoinfibre/bitcoinfibre";
  };
}
