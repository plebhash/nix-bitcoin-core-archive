{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? (pkgs."util-linux" or pkgs.utillinux)
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? import ../_deps/miniupnpc-2.2.2.nix { pkgs = pkgs; }
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, sqlite ? pkgs.sqlite
}:

with lib;
let
  version = "27.0";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-27.0/bitcoin-27.0.tar.gz"
    ];
    sha256 = "9c1ee651d3b157baccc3388be28b8cf3bfcefcd2493b943725ad6040ca6b146b";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent zeromq zlib miniupnpc sqlite ];

  configureFlags = [
    "--disable-bench"
    "--disable-tests"
    "--disable-gui"
    "--with-boost-libdir=${boost.out}/lib"
  ];

  meta = {
    description = "Bitcoin Core 27.0";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
