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
  version = "23.2";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-23.2/bitcoin-23.2.tar.gz"
    ];
    sha256 = "b254d316e4e783965ffda84b84beadf1a11184f50db5f00666d265867aaf1e7e";
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
    description = "Bitcoin Core 23.2";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
