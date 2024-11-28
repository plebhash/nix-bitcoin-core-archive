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
# todo: blocked by https://github.com/NixOS/nixpkgs/issues/359902
# , libmultiprocess ? pkgs.libmultiprocess
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
    rev = "b2ad32fb7cdda6e0d06f08320c4b1e1b17356bda";
    hash = "sha256-+S+YBCssxxXe5CcGabhucEZ33iVMpDiGUHH+yKRPEZQ=";
  };

  nativeBuildInputs =
    [ cmake pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ libmultiprocess boost libevent db48 sqlite miniupnpc zeromq zlib ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DENABLE_WALLET=ON"
    "-DBUILD_TESTS=OFF"
    "-DSECP256K1_BUILD_TESTS=OFF"
    "-DWITH_SV2=ON"
    "-DWITH_MULTIPROCESS=ON"
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
