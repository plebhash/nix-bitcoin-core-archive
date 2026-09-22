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
  version = "0.10.4";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.10.4.tar.gz"
    ];
    sha256 = "aa38ba400771cfa76d492e30ff322cd0da166f28ebbb254ea982b8cbc780a084";
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
    description = "Bitcoin Core 0.10.4";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
