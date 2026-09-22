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
  version = "0.9.1";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.9.1.tar.gz"
    ];
    sha256 = "958dd67274acbc18ea245ec1ec65d6c6e9d99ec819a9bd7af6494cfd22710d48";
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
    description = "Bitcoin Core 0.9.1";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
