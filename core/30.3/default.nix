{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, pkg-config ? pkgs.pkg-config
, cmake ? pkgs.cmake
, ninja ? pkgs.ninja
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, zeromq ? pkgs.zeromq, libsodium ? pkgs.libsodium
, zlib ? pkgs.zlib
, sqlite ? pkgs.sqlite
, python3 ? pkgs.python3
}:

with lib;
let
  version = "30.3";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-30.3/bitcoin-30.3.tar.gz"
    ];
    sha256 = "ef8a2dce3f18cd451fc928f2fe57f1ddda21fcde9e91879de2825b146c80526a";
  };

  nativeBuildInputs = [ cmake ninja pkg-config python3 ];

  buildInputs = [ boost libevent zeromq zlib sqlite libsodium ];

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_TX=OFF"
    "-DBUILD_UTIL=OFF"
    "-DBUILD_BENCH=OFF"
    "-DBUILD_GUI=OFF"
    "-DWITH_ZMQ=ON"
    "-DENABLE_IPC=OFF"
    "-DENABLE_HARDENING=OFF"
  ];

  meta = {
    description = "Bitcoin Core 30.3";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
