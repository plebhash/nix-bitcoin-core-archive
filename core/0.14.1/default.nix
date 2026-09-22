{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? (pkgs."pkg-config" or pkgs.pkgconfig)
, util-linux ? (pkgs."util-linux" or pkgs.utillinux)
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? pkgs.miniupnpc
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, db48 ? pkgs.db48, openssl ? pkgs.openssl
}:

with lib;
let
  version = "0.14.1";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.14.1.tar.gz"
    ];
    sha256 = "798b8da23a9e1df797b8c20c01f3e3f1b9710efd2556274707b245ee9dfc9961";
  };


  # Boost >= 1.69 multi_index requires const comparators. Upstream made
  # these const in v0.15.2; patch the pre-0.15.2 ones the same way.
  postUnpack = ''
    sed -i -E 's/^( *bool operator\(\)\(const .*& *b\))$/\1 const/' "$sourceRoot"/src/miner.h "$sourceRoot"/src/txmempool.h
    sed -i -E 's/^( *bool UseDescendantScore\(const CTxMemPoolEntry &a\))$/\1 const/' "$sourceRoot"/src/txmempool.h
  '';
  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent zeromq zlib miniupnpc db48 openssl ];

  configureFlags = [
    "--disable-bench"
    "--disable-tests"
    "--disable-gui"
    "--with-boost-libdir=${boost.out}/lib"
  ];

  meta = {
    description = "Bitcoin Core 0.14.1";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
