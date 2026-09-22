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
  version = "28.1";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-28.1/bitcoin-28.1.tar.gz"
    ];
    sha256 = "c5ae2dd041c7f9d9b7c722490ba5a9d624f7e9a089c67090615e1ba4ad0883ba";
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
    description = "Bitcoin Core 28.1";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
