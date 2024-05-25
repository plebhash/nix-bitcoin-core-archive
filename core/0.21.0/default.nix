{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } 
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? pkgs.util-linux
, hexdump ? pkgs.hexdump
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? pkgs.miniupnpc
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, db48 ? pkgs.db48
, sqlite ? pkgs.sqlite
, qrencode ? pkgs.qrencode 
, python3 ? pkgs.python3
, wrapQtAppsHook ? pkgs.qt5.wrapQtAppsHook
, qtbase ? pkgs.qt5.qtbase
, qttools ? pkgs.qt5.qttools
, nixosTests ? pkgs.nixosTests
}:

with lib;
let
  version = "0.21.0";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-${version}/bitcoin-${version}.tar.gz"
      "https://bitcoin.org/bin/bitcoin-core-${version}/bitcoin-${version}.tar.gz"
    ];
    sha256 = "1a91202c62ee49fb64d57a52b8d6d01cd392fffcbef257b573800f9289655f37";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config wrapQtAppsHook ]
    ++ lib.optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent miniupnpc zeromq zlib db48 sqlite qrencode qtbase qttools ];

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-tests"
    "--disable-gui-tests"
    "--with-gui=qt5"
    "--with-qt-bindir=${qtbase.dev}/bin:${qttools.dev}/bin"
  ];

  checkInputs = [ python3 ];

  doCheck = true;

  checkFlags = [ "LC_ALL=en_US.UTF-8" ];

  enableParallelBuilding = true;

  passthru.tests = {
    smoke-test = nixosTests.bitcoind;
  };

  meta = {
    description = "Bitcoin Core 0.21.0";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
