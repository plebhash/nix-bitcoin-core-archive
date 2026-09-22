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
  version = "30.1";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v30.1.tar.gz"
    ];
    sha256 = "6580d24ab4b882b1c1e7e2ddf8275be7c6b283ef57544b490551e86f2fb61a51";
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
    description = "Bitcoin Core 30.1";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
