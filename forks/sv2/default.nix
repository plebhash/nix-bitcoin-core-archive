{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? pkgs.util-linux
, hexdump ? pkgs.hexdump
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
  version = "v25.99.0";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind-sv2";
  inherit version;

  src = fetchFromGitHub {
    owner = "Sjors";
    repo = "bitcoin";
    rev = "3e83cd742c0e488be3752d623b70db2d57530ed0";
    hash = "sha256-DDkbcbjIQSaQSTFeq5ZLW3xMyITgNQ6ncGEHQY98DNQ=";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent db48 sqlite miniupnpc zeromq zlib ];

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-tests"
    "--disable-gui-tests"
    "--disable-fuzz"
    "--disable-fuzz-binary"
    "--disable-bench"
  ];

  checkInputs = [ python3 ];

  doCheck = false;

  checkFlags = [ "LC_ALL=en_US.UTF-8" ];

  enableParallelBuilding = true;

  meta = {
    description = "Bitcoin Core with a StratumV2 patch";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
