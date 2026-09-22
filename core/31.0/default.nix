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
  version = "31.0";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-31.0/bitcoin-31.0.tar.gz"
    ];
    sha256 = "0ba0ef5eea3aefd96cc1774be274c3d594812cfac0988809d706738bb067b3e3";
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
    description = "Bitcoin Core 31.0";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
