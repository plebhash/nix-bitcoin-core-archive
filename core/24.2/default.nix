{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? (pkgs."util-linux" or pkgs.utillinux)
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? import ../_deps/miniupnpc-1.9.nix { pkgs = pkgs; }
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, db48 ? pkgs.db48
}:

with lib;
let
  version = "24.2";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-24.2/bitcoin-24.2.tar.gz"
    ];
    sha256 = "20882834a5a8d1509f40a0452b09d94171cfc41342a6d3ac96fc19dff73b44e2";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent zeromq zlib miniupnpc db48 db48.dev ];

  configureFlags = [
    "--disable-bench"
    "--disable-tests"
    "--disable-gui"
    "--with-boost-libdir=${boost.out}/lib"
  ];

  meta = {
    description = "Bitcoin Core 24.2";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
