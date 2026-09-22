{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? (pkgs."pkg-config" or pkgs.pkgconfig)
, util-linux ? (pkgs."util-linux" or pkgs.utillinux)
, boost ? pkgs.boost
, db48 ? pkgs.db48
, glib ? pkgs.glib
, zlib ? pkgs.zlib
, openssl ? import ../_deps/openssl-1.0.2.nix { pkgs = pkgs; }
, libevent ? pkgs.libevent
, miniupnpc ? import ../_deps/miniupnpc-1.7.nix { pkgs = pkgs; }
}:

with lib;
let
  version = "0.11.2";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-0.11.2/bitcoin-0.11.2.tar.gz"
    ];
    sha256 = "a4d2bd642e5f7f1f82dc3f708618ac77e1e45353db7a98bf81c3bdc0e10690d3";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost db48 openssl glib zlib miniupnpc ];

  configureFlags = [
    "LDFLAGS=-ldl"
    "--disable-tests"
    "CXXFLAGS=-fpermissive"
    "--with-boost-libdir=${boost.out}/lib"
  ];

  meta = {
    description = "Bitcoin Core 0.11.2";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
