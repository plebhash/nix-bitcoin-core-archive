{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } 
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? pkgs.util-linux
, hexdump ? pkgs.hexdump
, autoSignDarwinBinariesHook ? pkgs.autoSignDarwinBinariesHook
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? pkgs.miniupnpc
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, db48 ? pkgs.db48
, sqlite ? pkgs.sqlite
, qrencode ? pkgs.qrencode 
, python3 ? pkgs.python3
, nixosTests ? pkgs.nixosTests
}:

with lib;
let
  version = "v26.99.0-ga9c93227f248ac9f6dcaa194aab17675394d8c3e";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind-sv2";
  inherit version;

  src = fetchFromGitHub {
    owner = "Sjors";
    repo = "bitcoin";
    rev = "a9c93227f248ac9f6dcaa194aab17675394d8c3e";
    hash = "sha256-7/UFIUhl5WA1GKjU+KdSCFPCJGdxZ+vgK3gAotaFxxU=";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ]
    ++ optionals stdenv.isDarwin [ hexdump ]
    ++ optionals (stdenv.isDarwin && stdenv.isAarch64) [ autoSignDarwinBinariesHook ];

  buildInputs = [ boost libevent miniupnpc zeromq zlib ];

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-wallet"
    "--disable-tests"
    "--disable-gui-tests"
  ];

  checkInputs = [ python3 ];

  doCheck = false;

  checkFlags = [ "LC_ALL=en_US.UTF-8" ];

  enableParallelBuilding = true;
}
