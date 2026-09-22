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
  version = "30.2";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-30.2/bitcoin-30.2.tar.gz"
    ];
    sha256 = "6fd00b8c42883d5c963901ad4109a35be1e5ec5c2dc763018c166c21a06c84cb";
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
    description = "Bitcoin Core 30.2";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
