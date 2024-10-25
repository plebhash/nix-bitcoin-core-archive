{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
, cmake ? pkgs.cmake
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
  version = "v28.99.0";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind-sv2-ipc";
  inherit version;

  src = fetchFromGitHub {
    owner = "Sjors";
    repo = "bitcoin";
    rev = "54b2da1b9a977a325a299c6fa7bdeba76452f2a8";
    hash = "sha256-nyIcLYk4PHDDD/g6iZphctijHc3y8jGHF7d3Y5t8q58=";
  };

  nativeBuildInputs =
    [ cmake pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent db48 sqlite miniupnpc zeromq zlib ];

  cmakeFlages = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DENABLE_WALLET=ON"
    "-DBUILD_TESTS=OFF"
    "-DSECP256K1_BUILD_TESTS=OFF"
    "-DWITH_SV2=ON"
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
