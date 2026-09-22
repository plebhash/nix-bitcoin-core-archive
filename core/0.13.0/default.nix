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
  version = "0.13.0";
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-0.13.0/bitcoin-0.13.0.tar.gz"
    ];
    sha256 = "0c7d7049689bb17f4256f1e5ec20777f42acef61814d434b38e6c17091161cda";
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
    description = "Bitcoin Core 0.13.0";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
