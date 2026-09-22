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
  version = "29.2";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-29.2/bitcoin-29.2.tar.gz"
    ];
    sha256 = "a529d75d0512317d6334bb9fd74cb6ddca3b1eb345d2e9e31b66136583ecc045";
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
    description = "Bitcoin Core 29.2";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
